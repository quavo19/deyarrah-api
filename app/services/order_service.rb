require "set"

class OrderService
  class ValidationError < StandardError; end
  class AvailabilityConflictError < StandardError; end
  class DowntimeConflictError < StandardError; end
  class RedisUnavailableError < StandardError; end
  def initialize(user, order_items_params, fulfillments_params = [], address_data = nil, phones = [], terms_metadata = {})
    @user = user
    @order_items_params = order_items_params
    @fulfillments_params = fulfillments_params
    @address_data = address_data
    @phones = phones
    @terms_metadata = terms_metadata || {}
    @redis_reservations = []
    @locks = []
  end

  def create
    validate_order_items_structure
    validate_variant_stocks
    validate_fulfillments_structure
    validate_fulfillments_coverage
    validate_warehouse_match

    variant_stock_ids = @order_items_params.map { |item| item[:variant_stock_id] }.uniq.sort

    begin
      ensure_redis_initialized(variant_stock_ids)
      acquire_locks(variant_stock_ids)
      atomic_reserve_all

      order = nil
      ActiveRecord::Base.transaction do
        validate_active_downtimes

        order = Order.new(
          user: @user,
          status: :pending
        )

        if @terms_metadata[:accepted_at].present?
          order.terms_accepted_at = @terms_metadata[:accepted_at]
          order.terms_version = @terms_metadata[:version]
        end

        # Store address data directly on order if provided
        if @address_data.present?
          order.customer_address_id = @address_data[:customer_address_id] || @address_data["customer_address_id"]
          order.delivery_address_name = @address_data[:name] || @address_data["name"]
          order.delivery_latitude = @address_data[:latitude] || @address_data["latitude"]
          order.delivery_longitude = @address_data[:longitude] || @address_data["longitude"]
        end

        # Store phones directly on order (array of strings)
        order.phones = Array(@phones).map(&:to_s)

        # Build order_items and associate them with the order
        order_items = []
        @order_items_params.each do |item_params|
          # We only have a real association to :warehouse; :variant_options is a helper method,
          # so we fetch it normally instead of trying to preload a non-existent association.
          variant_stock = VariantStock.includes(:warehouse).find_by(id: item_params[:variant_stock_id])
          unless variant_stock
            raise ValidationError, "Variant stock #{item_params[:variant_stock_id]} not found"
          end

          warehouse = variant_stock.warehouse
          variant_options = variant_stock.variant_options.includes(:variant_type)

          order_item = order.order_items.build(
            variant_stock_id: item_params[:variant_stock_id],
            quantity: item_params[:quantity]
          )

          # Store variant_stock snapshot data directly on order_item (standalone, no UUIDs)
          order_item.variant_stock_price = variant_stock.price
          order_item.variant_stock_quantity = variant_stock.quantity

          # Store option names as text (format: "Type1: Option1, Option2 / Type2: Option3")
          option_names_parts = variant_options.reject { |option| option.variant_type.pricing_role == "base" }.group_by { |opt| opt.variant_type.name }.map do |type_name, options|
            "#{type_name}: #{options.map(&:name).join(', ')}"
          end
          order_item.variant_stock_option_names = option_names_parts.join(" / ")

          # Store full warehouse information
          order_item.variant_stock_warehouse_name = warehouse.name
          order_item.variant_stock_warehouse_address = warehouse.address || {}
          order_item.variant_stock_warehouse_latitude = warehouse.latitude
          order_item.variant_stock_warehouse_longitude = warehouse.longitude
          order_item.variant_stock_warehouse_country = warehouse.country
          order_item.variant_stock_warehouse_region = warehouse.region
          order_item.variant_stock_warehouse_city = warehouse.city
          order_item.variant_stock_warehouse_county = warehouse.county

          order_items << order_item
        end

        save_order_with_unique_id(order)

        # Reload to ensure order_items have IDs
        order.reload
        order_items = order.order_items.to_a

        create_fulfillments(order, order_items)

        # Calculate and update delivery fees and totals
        calculate_and_update_pricing(order)
      end

      order
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
    rescue ActiveRecord::RecordInvalid => e
      release_locks
      rollback_redis_reservations
      Rails.logger.error("OrderService validation error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      raise ValidationError, e.message
    rescue DeliveryFeeCalculator::DeliveryUnavailableError => e
      release_locks
      rollback_redis_reservations
      raise ValidationError, e.message
    rescue StandardError => e
      release_locks
      rollback_redis_reservations
      Rails.logger.error("OrderService error: #{e.class.name}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      raise
    ensure
      release_locks
    end
  end

  private

  def validate_order_items_structure
    if @order_items_params.blank? || !@order_items_params.is_a?(Array)
      raise ValidationError, "order_items must be an array"
    end

    if @order_items_params.empty?
      raise ValidationError, "at least one order_item is required"
    end

    @order_items_params.each do |item|
      unless item.is_a?(Hash)
        raise ValidationError, "each order_item must be a hash"
      end

      unless item[:variant_stock_id].present?
        raise ValidationError, "variant_stock_id is required for each order_item"
      end

      unless item[:quantity].present? && item[:quantity].to_i > 0
        raise ValidationError, "quantity must be a positive integer for each order_item"
      end
    end
  end

  def validate_variant_stocks
    variant_stock_ids = @order_items_params.map { |item| item[:variant_stock_id] }
    variant_stocks = VariantStock.where(id: variant_stock_ids)

    if variant_stocks.count != variant_stock_ids.count
      raise ValidationError, "one or more variant_stocks not found"
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

      order_items = fulfillment_hash[:order_items] || fulfillment_hash["order_items"]
      unless order_items.present? && order_items.is_a?(Array)
        raise ValidationError, "order_items array is required for fulfillment at index #{index}"
      end

      if order_items.empty?
        raise ValidationError, "at least one order_item is required for fulfillment at index #{index}"
      end

      order_items.each_with_index do |item, item_index|
        item_hash = item.is_a?(Hash) ? item : item.to_h
        unless item_hash.is_a?(Hash)
          raise ValidationError, "order_item at index #{item_index} in fulfillment #{index} must be a hash"
        end

        variant_stock_id = item_hash[:variant_stock_id] || item_hash["variant_stock_id"]
        unless variant_stock_id.present?
          raise ValidationError, "variant_stock_id is required for order_item at index #{item_index} in fulfillment #{index}"
        end

        quantity = item_hash[:quantity] || item_hash["quantity"]
        unless quantity.present? && quantity.to_i > 0
          raise ValidationError, "quantity must be a positive integer for order_item at index #{item_index} in fulfillment #{index}"
        end
      end
    end
  end

  def validate_fulfillments_coverage
    # Create a map of variant_stock_id => total quantity requested in order_items
    order_items_map = {}
    @order_items_params.each do |item|
      item_hash = item.is_a?(Hash) ? item : item.to_h
      variant_stock_id = (item_hash[:variant_stock_id] || item_hash["variant_stock_id"]).to_s
      quantity = (item_hash[:quantity] || item_hash["quantity"]).to_i
      order_items_map[variant_stock_id] = (order_items_map[variant_stock_id] || 0) + quantity
    end

    # Create a map of variant_stock_id => total quantity assigned in fulfillments
    fulfillments_map = {}
    @fulfillments_params.each do |fulfillment|
      fulfillment_hash = fulfillment.is_a?(Hash) ? fulfillment : fulfillment.to_h
      order_items = fulfillment_hash[:order_items] || fulfillment_hash["order_items"] || []
      order_items.each do |item|
        item_hash = item.is_a?(Hash) ? item : item.to_h
        variant_stock_id = (item_hash[:variant_stock_id] || item_hash["variant_stock_id"]).to_s
        quantity = (item_hash[:quantity] || item_hash["quantity"]).to_i
        fulfillments_map[variant_stock_id] = (fulfillments_map[variant_stock_id] || 0) + quantity
      end
    end

    # Check that all order_items are covered
    order_items_map.each do |variant_stock_id, requested_quantity|
      fulfilled_quantity = fulfillments_map[variant_stock_id] || 0
      if fulfilled_quantity != requested_quantity
        raise ValidationError, "Fulfillment quantities do not match order_items for variant_stock #{variant_stock_id}. Requested: #{requested_quantity}, Fulfilled: #{fulfilled_quantity}"
      end
    end

    # Check that fulfillments don't exceed order_items
    fulfillments_map.each do |variant_stock_id, fulfilled_quantity|
      requested_quantity = order_items_map[variant_stock_id] || 0
      if fulfilled_quantity > requested_quantity
        raise ValidationError, "Fulfillment quantity exceeds order_items for variant_stock #{variant_stock_id}. Requested: #{requested_quantity}, Fulfilled: #{fulfilled_quantity}"
      end
    end
  end

  def validate_warehouse_match
    variant_stock_ids = @order_items_params.map do |item|
      item_hash = item.is_a?(Hash) ? item : item.to_h
      item_hash[:variant_stock_id] || item_hash["variant_stock_id"]
    end
    variant_stocks = VariantStock.where(id: variant_stock_ids).includes(:warehouse).index_by(&:id)

    @fulfillments_params.each do |fulfillment|
      fulfillment_hash = fulfillment.is_a?(Hash) ? fulfillment : fulfillment.to_h
      warehouse_id = (fulfillment_hash[:warehouse_id] || fulfillment_hash["warehouse_id"]).to_s
      order_items = fulfillment_hash[:order_items] || fulfillment_hash["order_items"] || []

      order_items.each do |item|
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
    reservations = @order_items_params.map do |item_params|
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

  def validate_active_downtimes
    variant_stock_ids = @order_items_params.map { |item| item[:variant_stock_id] }.uniq

    VariantStock.where(id: variant_stock_ids).lock("FOR UPDATE").each do |variant_stock|
      active_downtimes = variant_stock.downtimes
        .where("start_at <= ? AND end_at > ?", Time.current, Time.current)
        .where(ended_at: nil)

      if active_downtimes.exists?
        raise DowntimeConflictError, "Variant stock #{variant_stock.id} is currently in downtime"
      end
    end
  end

  def create_fulfillments(order, order_items)
    # Track assigned order_items to ensure each is only assigned once
    assigned_order_item_ids = Set.new

    @fulfillments_params.each do |fulfillment_params|
      # Handle both symbol and string keys
      fulfillment_hash = fulfillment_params.is_a?(Hash) ? fulfillment_params : fulfillment_params.to_h
      warehouse_id = fulfillment_hash[:warehouse_id] || fulfillment_hash["warehouse_id"]
      delivery_date = fulfillment_hash[:delivery_date] || fulfillment_hash["delivery_date"]
      delivery_fee = fulfillment_hash[:delivery_fee] || fulfillment_hash["delivery_fee"]
      order_items_params = fulfillment_hash[:order_items] || fulfillment_hash["order_items"] || []

      # Fetch warehouse to get coordinates
      warehouse = Warehouse.find_by(id: warehouse_id)
      unless warehouse
        raise ValidationError, "Warehouse #{warehouse_id} not found"
      end

      fulfillment = Fulfillment.create!(
        order: order,
        warehouse_id: warehouse_id,
        warehouse_latitude: warehouse.latitude,
        warehouse_longitude: warehouse.longitude,
        status: :pending,
        delivery_date: delivery_date ? Time.parse(delivery_date) : nil,
        delivery_fee: delivery_fee
      )

      # For each order_item in the fulfillment params, find and assign the matching order_item
      order_items_params.each do |item_params|
        item_hash = item_params.is_a?(Hash) ? item_params : item_params.to_h
        variant_stock_id = (item_hash[:variant_stock_id] || item_hash["variant_stock_id"]).to_s
        quantity = (item_hash[:quantity] || item_hash["quantity"]).to_i

        # Find an unassigned order_item that matches this variant_stock_id and quantity
        matching_item = order_items.find do |order_item|
          !assigned_order_item_ids.include?(order_item.id) &&
          order_item.variant_stock_id.to_s == variant_stock_id &&
          order_item.quantity == quantity
        end

        unless matching_item
          raise ValidationError, "Could not find matching order_item for variant_stock #{variant_stock_id} with quantity #{quantity} in fulfillment"
        end

        # Create fulfillment_item linking this order_item to the fulfillment
        FulfillmentItem.create!(
          fulfillment: fulfillment,
          order_item: matching_item
        )
        assigned_order_item_ids.add(matching_item.id)
      end
    end

    # Ensure all order_items were assigned
    unassigned_items = order_items.reject { |item| assigned_order_item_ids.include?(item.id) }
    if unassigned_items.any?
      raise ValidationError, "Some order_items were not assigned to fulfillments: #{unassigned_items.map(&:id).join(', ')}"
    end
  end

  def calculate_and_update_pricing(order)
    # Reload order to ensure we have latest data
    order.reload

    # Calculate item subtotal (sum of all order item prices)
    item_subtotal = order.order_items.sum { |item| item.price }

    # Calculate configured delivery fees for each fulfillment.
    total_delivery_fee = 0.0
    total_delivery_distance = 0.0

    if order.customer_address.present?
      order.fulfillments.each do |fulfillment|
        warehouse = fulfillment.warehouse
        unless warehouse&.country == "Ghana"
          raise ValidationError, "We do not deliver outside Ghana"
        end

        delivery_fee = DeliveryFeeCalculator.new(fulfillment).calculate

        fulfillment.update!(
          delivery_fee: delivery_fee
        )

        total_delivery_fee += delivery_fee
      end
    end

    # Calculate total amount
    total_amount = item_subtotal + total_delivery_fee

    # Update order with calculated values
    order.update!(
      delivery_distance: total_delivery_distance.round(2),
      delivery_fee: total_delivery_fee.round(2),
      item_subtotal: item_subtotal.round(2),
      total_amount: total_amount.round(2)
    )

    # Reload to ensure updated values are available
    order.reload
  end

  def save_order_with_unique_id(order)
    attempts = 0

    begin
      order.save!
    rescue ActiveRecord::RecordNotUnique => e
      raise if (attempts += 1) > 5

      order.order_id = nil
      order.send(:ensure_order_id)
      retry
    end
  end

  def delivery_rate_for_fulfillment(_fulfillment)
    10.0
  end
end
