require "set"

class BookingService
  class ValidationError < StandardError; end
  class AvailabilityConflictError < StandardError; end
  class DowntimeConflictError < StandardError; end
  class RedisUnavailableError < StandardError; end
  class TimeRangeInvalidError < StandardError; end
  class BookingOverlapError < StandardError; end

  def initialize(user, product, start_at, end_at, booking_items_params, fulfillments_params = [], address_data = nil, phones = [])
    @user = user
    @product = product
    @start_at = start_at
    @end_at = end_at
    @booking_items_params = booking_items_params
    @fulfillments_params = fulfillments_params
    @address_data = address_data
    @phones = phones
    @redis_reservations = []
    @locks = []
  end

  def create
    validate_date_range
    validate_booking_items_structure
    validate_product_match
    validate_fulfillments_structure
    validate_fulfillments_coverage
    validate_warehouse_match

    variant_stock_ids = @booking_items_params.map { |item| item[:variant_stock_id] }.uniq.sort

    begin
      ensure_redis_initialized(variant_stock_ids)
      validate_time_based_availability
      acquire_locks(variant_stock_ids)
      atomic_reserve_all

      booking = nil
      ActiveRecord::Base.transaction do
        validate_db_time_overlaps

        # Build booking first (don't save yet to avoid validation error)
        booking = Booking.new(
          user: @user,
          product: @product,
          start_at: @start_at,
          end_at: @end_at,
          status: :pending
        )

        # Store address data directly on booking if provided
        if @address_data.present?
          booking.delivery_address_name = @address_data[:name] || @address_data["name"]
          booking.delivery_latitude = @address_data[:latitude] || @address_data["latitude"]
          booking.delivery_longitude = @address_data[:longitude] || @address_data["longitude"]
        end

        # Store product snapshot data directly on booking
        booking.product_name = @product.name
        booking.product_description = @product.description
        booking.product_bookable_type = @product.bookable_type
        booking.product_delivery_rate_per_km = @product.delivery_rate_per_km || 10.0

        # Store phones directly on booking (array of strings)
        booking.phones = Array(@phones).map(&:to_s)

        # Build booking_items and associate them with the booking
        booking_items = []
        @booking_items_params.each do |item_params|
          # We only have a real association to :warehouse; :variant_options is a helper method,
          # so we fetch it normally instead of trying to preload a non-existent association.
          variant_stock = VariantStock.includes(:warehouse).find_by(id: item_params[:variant_stock_id])
          unless variant_stock
            raise ValidationError, "Variant stock #{item_params[:variant_stock_id]} not found"
          end

          warehouse = variant_stock.warehouse
          variant_options = variant_stock.variant_options

          booking_item = booking.booking_items.build(
            variant_stock_id: item_params[:variant_stock_id],
            quantity: item_params[:quantity]
          )

          # Store variant_stock snapshot data directly on booking_item (standalone, no UUIDs)
          booking_item.variant_stock_price = variant_stock.price
          booking_item.variant_stock_quantity = variant_stock.quantity

          # Store option names as text (format: "Type1: Option1, Option2 / Type2: Option3")
          option_names_parts = variant_options.group_by { |opt| opt.variant_type.name }.map do |type_name, options|
            "#{type_name}: #{options.map(&:name).join(', ')}"
          end
          booking_item.variant_stock_option_names = option_names_parts.join(" / ")

          # Store full warehouse information
          booking_item.variant_stock_warehouse_name = warehouse.name
          booking_item.variant_stock_warehouse_address = warehouse.address || {}
          booking_item.variant_stock_warehouse_latitude = warehouse.latitude
          booking_item.variant_stock_warehouse_longitude = warehouse.longitude
          booking_item.variant_stock_warehouse_country = warehouse.country
          booking_item.variant_stock_warehouse_region = warehouse.region
          booking_item.variant_stock_warehouse_city = warehouse.city
          booking_item.variant_stock_warehouse_county = warehouse.county

          booking_items << booking_item
        end

        # Save the booking (this will autosave the booking_items and validation will pass)
        booking.save!

        # Reload to ensure booking_items have IDs
        booking.reload
        booking_items = booking.booking_items.to_a

        create_fulfillments(booking, booking_items)

        # Calculate and update delivery fees and totals
        calculate_and_update_pricing(booking)
      end

      booking
    rescue AvailabilityStore::RedisUnavailableError => e
      release_locks
      raise RedisUnavailableError, e.message
    rescue AvailabilityStore::DowntimeConflictError => e
      release_locks
      rollback_redis_reservations
      raise DowntimeConflictError, e.message
    rescue AvailabilityStore::InsufficientAvailabilityError => e
      release_locks
      rollback_redis_reservations
      raise AvailabilityConflictError, "Insufficient availability: #{e.message}"
    rescue AvailabilityStore::AvailabilityError => e
      release_locks
      rollback_redis_reservations
      raise AvailabilityConflictError, e.message
    rescue AvailabilityStore::LockError => e
      rollback_redis_reservations
      raise AvailabilityConflictError, "Concurrency conflict: #{e.message}"
    rescue TimeBasedAvailabilityChecker::TimeRangeInvalidError => e
      raise TimeRangeInvalidError, e.message
    rescue TimeBasedAvailabilityChecker::BookingOverlapError => e
      raise BookingOverlapError, e.message
    rescue TimeBasedAvailabilityChecker::DowntimeConflictError => e
      raise DowntimeConflictError, e.message
    rescue ActiveRecord::RecordInvalid => e
      release_locks
      rollback_redis_reservations
      Rails.logger.error("BookingService validation error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      raise ValidationError, e.message
    rescue StandardError => e
      release_locks
      rollback_redis_reservations
      Rails.logger.error("BookingService error: #{e.class.name}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      raise
    ensure
      release_locks
    end
  end

  private

  def validate_date_range
    if @start_at.blank? || @end_at.blank?
      raise ValidationError, "start_at and end_at are required"
    end

    if @end_at <= @start_at
      raise ValidationError, "end_at must be after start_at"
    end

    if @start_at < Time.current
      raise ValidationError, "start_at cannot be in the past"
    end
  end

  def validate_booking_items_structure
    if @booking_items_params.blank? || !@booking_items_params.is_a?(Array)
      raise ValidationError, "booking_items must be an array"
    end

    if @booking_items_params.empty?
      raise ValidationError, "at least one booking_item is required"
    end

    @booking_items_params.each do |item|
      unless item.is_a?(Hash)
        raise ValidationError, "each booking_item must be a hash"
      end

      unless item[:variant_stock_id].present?
        raise ValidationError, "variant_stock_id is required for each booking_item"
      end

      unless item[:quantity].present? && item[:quantity].to_i > 0
        raise ValidationError, "quantity must be a positive integer for each booking_item"
      end
    end
  end

  def validate_product_match
    variant_stock_ids = @booking_items_params.map { |item| item[:variant_stock_id] }
    variant_stocks = VariantStock.where(id: variant_stock_ids)

    if variant_stocks.count != variant_stock_ids.count
      raise ValidationError, "one or more variant_stocks not found"
    end

    variant_stocks.each do |variant_stock|
      stock_product = variant_stock.product
      if stock_product.nil? && !variant_stock.unit_product?
        raise ValidationError, "variant_stock #{variant_stock.id} does not belong to a product"
      end

      if !variant_stock.unit_product? && stock_product.id != @product.id
        raise ValidationError, "variant_stock #{variant_stock.id} does not belong to product #{@product.id}"
      end
    end
  end

  def validate_fulfillments_structure
    if @fulfillments_params.blank? || !@fulfillments_params.is_a?(Array)
      raise ValidationError, "fulfillments must be an array"
    end

    if @fulfillments_params.empty?
      raise ValidationError, "at least one fulfillment is required"
    end

    @fulfillments_params.each_with_index do |fulfillment, index|
      # Handle both symbol and string keys
      fulfillment_hash = fulfillment.is_a?(Hash) ? fulfillment : fulfillment.to_h

      unless fulfillment_hash.is_a?(Hash)
        raise ValidationError, "fulfillment at index #{index} must be a hash"
      end

      warehouse_id = fulfillment_hash[:warehouse_id] || fulfillment_hash["warehouse_id"]
      unless warehouse_id.present?
        raise ValidationError, "warehouse_id is required for fulfillment at index #{index}"
      end

      booking_items = fulfillment_hash[:booking_items] || fulfillment_hash["booking_items"]
      unless booking_items.present? && booking_items.is_a?(Array)
        raise ValidationError, "booking_items array is required for fulfillment at index #{index}"
      end

      if booking_items.empty?
        raise ValidationError, "at least one booking_item is required for fulfillment at index #{index}"
      end

      booking_items.each_with_index do |item, item_index|
        item_hash = item.is_a?(Hash) ? item : item.to_h
        unless item_hash.is_a?(Hash)
          raise ValidationError, "booking_item at index #{item_index} in fulfillment #{index} must be a hash"
        end

        variant_stock_id = item_hash[:variant_stock_id] || item_hash["variant_stock_id"]
        unless variant_stock_id.present?
          raise ValidationError, "variant_stock_id is required for booking_item at index #{item_index} in fulfillment #{index}"
        end

        quantity = item_hash[:quantity] || item_hash["quantity"]
        unless quantity.present? && quantity.to_i > 0
          raise ValidationError, "quantity must be a positive integer for booking_item at index #{item_index} in fulfillment #{index}"
        end
      end
    end
  end

  def validate_fulfillments_coverage
    # Create a map of variant_stock_id => total quantity requested in booking_items
    booking_items_map = {}
    @booking_items_params.each do |item|
      item_hash = item.is_a?(Hash) ? item : item.to_h
      variant_stock_id = (item_hash[:variant_stock_id] || item_hash["variant_stock_id"]).to_s
      quantity = (item_hash[:quantity] || item_hash["quantity"]).to_i
      booking_items_map[variant_stock_id] = (booking_items_map[variant_stock_id] || 0) + quantity
    end

    # Create a map of variant_stock_id => total quantity assigned in fulfillments
    fulfillments_map = {}
    @fulfillments_params.each do |fulfillment|
      fulfillment_hash = fulfillment.is_a?(Hash) ? fulfillment : fulfillment.to_h
      booking_items = fulfillment_hash[:booking_items] || fulfillment_hash["booking_items"] || []
      booking_items.each do |item|
        item_hash = item.is_a?(Hash) ? item : item.to_h
        variant_stock_id = (item_hash[:variant_stock_id] || item_hash["variant_stock_id"]).to_s
        quantity = (item_hash[:quantity] || item_hash["quantity"]).to_i
        fulfillments_map[variant_stock_id] = (fulfillments_map[variant_stock_id] || 0) + quantity
      end
    end

    # Check that all booking_items are covered
    booking_items_map.each do |variant_stock_id, requested_quantity|
      fulfilled_quantity = fulfillments_map[variant_stock_id] || 0
      if fulfilled_quantity != requested_quantity
        raise ValidationError, "Fulfillment quantities do not match booking_items for variant_stock #{variant_stock_id}. Requested: #{requested_quantity}, Fulfilled: #{fulfilled_quantity}"
      end
    end

    # Check that fulfillments don't exceed booking_items
    fulfillments_map.each do |variant_stock_id, fulfilled_quantity|
      requested_quantity = booking_items_map[variant_stock_id] || 0
      if fulfilled_quantity > requested_quantity
        raise ValidationError, "Fulfillment quantity exceeds booking_items for variant_stock #{variant_stock_id}. Requested: #{requested_quantity}, Fulfilled: #{fulfilled_quantity}"
      end
    end
  end

  def validate_warehouse_match
    variant_stock_ids = @booking_items_params.map do |item|
      item_hash = item.is_a?(Hash) ? item : item.to_h
      item_hash[:variant_stock_id] || item_hash["variant_stock_id"]
    end
    variant_stocks = VariantStock.where(id: variant_stock_ids).includes(:warehouse).index_by(&:id)

    @fulfillments_params.each do |fulfillment|
      fulfillment_hash = fulfillment.is_a?(Hash) ? fulfillment : fulfillment.to_h
      warehouse_id = (fulfillment_hash[:warehouse_id] || fulfillment_hash["warehouse_id"]).to_s
      booking_items = fulfillment_hash[:booking_items] || fulfillment_hash["booking_items"] || []

      booking_items.each do |item|
        item_hash = item.is_a?(Hash) ? item : item.to_h
        variant_stock_id = (item_hash[:variant_stock_id] || item_hash["variant_stock_id"]).to_s
        variant_stock = variant_stocks[variant_stock_id]

        unless variant_stock
          raise ValidationError, "variant_stock #{variant_stock_id} not found"
        end

        if variant_stock.warehouse_id.to_s != warehouse_id
          raise ValidationError, "variant_stock #{variant_stock_id} does not belong to warehouse #{warehouse_id}. It belongs to warehouse #{variant_stock.warehouse_id}"
        end
      end
    end
  end

  def ensure_redis_initialized(variant_stock_ids)
    variant_stocks = VariantStock.where(id: variant_stock_ids).index_by(&:id)

    variant_stock_ids.each do |variant_stock_id|
      variant_stock = variant_stocks[variant_stock_id]
      unless variant_stock
        raise ValidationError, "Variant stock #{variant_stock_id} not found"
      end

      total = AvailabilityStore.get_total_quantity(variant_stock_id)
      if total.nil?
        AvailabilityStore.initialize_from_db(variant_stock)
      end
    end
  end

  def acquire_locks(variant_stock_ids)
    variant_stock_ids.each do |variant_stock_id|
      lock_value = AvailabilityStore.lock(variant_stock_id)
      @locks << { variant_stock_id: variant_stock_id, lock_value: lock_value }
    end
  end

  def release_locks
    @locks.each do |lock|
      begin
        AvailabilityStore.unlock(lock[:variant_stock_id], lock[:lock_value])
      rescue StandardError => e
        Rails.logger.error("Failed to release lock for variant_stock #{lock[:variant_stock_id]}: #{e.message}")
      end
    end
    @locks.clear
  end

  def atomic_reserve_all
    reservations = @booking_items_params.map do |item_params|
      {
        variant_stock_id: item_params[:variant_stock_id],
        quantity: item_params[:quantity].to_i
      }
    end

    AvailabilityStore.atomic_multi_reserve(reservations)

    @redis_reservations = reservations
  end

  def rollback_redis_reservations
    return if @redis_reservations.empty?

    begin
      AvailabilityStore.atomic_multi_restore(@redis_reservations)
    rescue StandardError => e
      Rails.logger.error("Failed to rollback Redis reservations: #{e.message}")
    end
    @redis_reservations.clear
  end

  def validate_time_based_availability
    variant_stock_ids = @booking_items_params.map { |item| item[:variant_stock_id] }.uniq
    variant_stocks = VariantStock.where(id: variant_stock_ids).index_by(&:id)

    variant_stocks.each do |variant_stock_id, variant_stock|
      item_params = @booking_items_params.select { |item| item[:variant_stock_id] == variant_stock_id.to_s || item[:variant_stock_id] == variant_stock_id }
      total_requested = item_params.sum { |item| item[:quantity].to_i }

      checker = TimeBasedAvailabilityChecker.new(
        @product,
        variant_stock,
        @start_at,
        @end_at,
        total_requested
      )

      checker.validate_availability
    end
  end

  def validate_db_time_overlaps
    variant_stock_ids = @booking_items_params.map { |item| item[:variant_stock_id] }.uniq

    VariantStock.where(id: variant_stock_ids).lock("FOR UPDATE").each do |variant_stock|
      item_params = @booking_items_params.select { |item| item[:variant_stock_id] == variant_stock.id.to_s || item[:variant_stock_id] == variant_stock.id }
      total_requested = item_params.sum { |item| item[:quantity].to_i }

      overlapping_bookings = Booking.active
        .joins(:booking_items)
        .where(booking_items: { variant_stock_id: variant_stock.id })
        .overlapping(@start_at, @end_at)

      if @product.unit?
        reserved_quantity = overlapping_bookings
          .joins(:booking_items)
          .where(booking_items: { variant_stock_id: variant_stock.id })
          .sum("booking_items.quantity")

        total_quantity = AvailabilityStore.get_total_quantity(variant_stock.id) || variant_stock.quantity
        available = total_quantity - reserved_quantity

        if available < total_requested
          raise BookingOverlapError, "Insufficient availability for variant stock #{variant_stock.id}. Available: #{available}, Requested: #{total_requested}"
        end
      elsif @product.bulk?
        reserved_quantity = overlapping_bookings
          .joins(:booking_items)
          .where(booking_items: { variant_stock_id: variant_stock.id })
          .sum("booking_items.quantity")

        total_quantity = AvailabilityStore.get_total_quantity(variant_stock.id) || variant_stock.quantity

        if reserved_quantity + total_requested > total_quantity
          raise BookingOverlapError, "Capacity exceeded for variant stock #{variant_stock.id}. Total: #{total_quantity}, Reserved: #{reserved_quantity}, Requested: #{total_requested}"
        end
      end

      overlapping_downtimes = variant_stock.downtimes
        .where("start_at < ? AND end_at > ?", @end_at, @start_at)
        .where(ended_at: nil)

      if overlapping_downtimes.exists?
        raise DowntimeConflictError, "Variant stock #{variant_stock.id} has overlapping downtime"
      end
    end
  end

  def create_fulfillments(booking, booking_items)
    # Track assigned booking_items to ensure each is only assigned once
    assigned_booking_item_ids = Set.new

    @fulfillments_params.each do |fulfillment_params|
      # Handle both symbol and string keys
      fulfillment_hash = fulfillment_params.is_a?(Hash) ? fulfillment_params : fulfillment_params.to_h
      warehouse_id = fulfillment_hash[:warehouse_id] || fulfillment_hash["warehouse_id"]
      delivery_date = fulfillment_hash[:delivery_date] || fulfillment_hash["delivery_date"]
      delivery_fee = fulfillment_hash[:delivery_fee] || fulfillment_hash["delivery_fee"]
      booking_items_params = fulfillment_hash[:booking_items] || fulfillment_hash["booking_items"] || []

      # Fetch warehouse to get coordinates
      warehouse = Warehouse.find_by(id: warehouse_id)
      unless warehouse
        raise ValidationError, "Warehouse #{warehouse_id} not found"
      end

      fulfillment = Fulfillment.create!(
        booking: booking,
        warehouse_id: warehouse_id,
        warehouse_latitude: warehouse.latitude,
        warehouse_longitude: warehouse.longitude,
        status: :pending,
        delivery_date: delivery_date ? Time.parse(delivery_date) : nil,
        delivery_fee: delivery_fee
      )

      # For each booking_item in the fulfillment params, find and assign the matching booking_item
      booking_items_params.each do |item_params|
        item_hash = item_params.is_a?(Hash) ? item_params : item_params.to_h
        variant_stock_id = (item_hash[:variant_stock_id] || item_hash["variant_stock_id"]).to_s
        quantity = (item_hash[:quantity] || item_hash["quantity"]).to_i

        # Find an unassigned booking_item that matches this variant_stock_id and quantity
        matching_item = booking_items.find do |booking_item|
          !assigned_booking_item_ids.include?(booking_item.id) &&
          booking_item.variant_stock_id.to_s == variant_stock_id &&
          booking_item.quantity == quantity
        end

        unless matching_item
          raise ValidationError, "Could not find matching booking_item for variant_stock #{variant_stock_id} with quantity #{quantity} in fulfillment"
        end

        # Create fulfillment_item linking this booking_item to the fulfillment
        FulfillmentItem.create!(
          fulfillment: fulfillment,
          booking_item: matching_item
        )
        assigned_booking_item_ids.add(matching_item.id)
      end
    end

    # Ensure all booking_items were assigned
    unassigned_items = booking_items.reject { |item| assigned_booking_item_ids.include?(item.id) }
    if unassigned_items.any?
      raise ValidationError, "Some booking_items were not assigned to fulfillments: #{unassigned_items.map(&:id).join(', ')}"
    end
  end

  def calculate_and_update_pricing(booking)
    # Reload booking to ensure we have latest data
    booking.reload

    # Calculate item subtotal (sum of all booking item prices)
    item_subtotal = booking.booking_items.sum { |item| item.price }

    # Calculate delivery fees and distance for each fulfillment
    total_delivery_fee = 0.0
    total_delivery_distance = 0.0

    # Get delivery address from stored fields
    if booking.delivery_latitude.present? && booking.delivery_longitude.present?
      booking.fulfillments.each do |fulfillment|
        # Use stored warehouse coordinates
        unless fulfillment.warehouse_latitude.present? && fulfillment.warehouse_longitude.present?
          raise ValidationError, "Warehouse coordinates not stored for fulfillment #{fulfillment.id}"
        end

        # Validate warehouse is in Ghana (still need to fetch warehouse for country check)
        warehouse = fulfillment.warehouse
        unless warehouse&.country == "Ghana"
          raise ValidationError, "We do not deliver outside Ghana"
        end

        # Calculate distance using stored coordinates
        distance = DistanceCalculator.calculate_distance(
          fulfillment.warehouse_latitude,
          fulfillment.warehouse_longitude,
          booking.delivery_latitude,
          booking.delivery_longitude
        )

        # Calculate delivery fee using stored product delivery_rate_per_km
        delivery_rate = booking.product_delivery_rate_per_km || @product.delivery_rate_per_km || 10.0
        delivery_fee = DistanceCalculator.calculate_delivery_fee(
          distance,
          delivery_rate
        )

        # Update fulfillment with calculated values
        fulfillment.update!(
          delivery_fee: delivery_fee
        )

        total_delivery_fee += delivery_fee
        total_delivery_distance += distance
      end
    end

    # Calculate total amount
    total_amount = item_subtotal + total_delivery_fee

    # Update booking with calculated values
    booking.update!(
      delivery_distance: total_delivery_distance.round(2),
      delivery_fee: total_delivery_fee.round(2),
      item_subtotal: item_subtotal.round(2),
      total_amount: total_amount.round(2)
    )

    # Reload to ensure updated values are available
    booking.reload
  end
end
