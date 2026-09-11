class TimeBasedAvailabilityChecker
  class TimeRangeInvalidError < StandardError; end
  class OrderOverlapError < StandardError; end
  class DowntimeConflictError < StandardError; end

  def initialize(product, variant_stock, start_at, end_at, requested_quantity)
    @product = product
    @variant_stock = variant_stock
    @start_at = start_at
    @end_at = end_at
    @requested_quantity = requested_quantity
  end

  def validate_time_range
    true
  end

  def check_downtime_overlap
    if AvailabilityStore.get_downtime_flag(@variant_stock.id)
      raise DowntimeConflictError, "Variant stock #{@variant_stock.id} is in downtime"
    end

    active_downtimes = @variant_stock.downtimes
      .where("start_at <= ? AND end_at > ?", Time.current, Time.current)
      .where(ended_at: nil)

    if active_downtimes.exists?
      raise DowntimeConflictError, "Variant stock #{@variant_stock.id} is currently in downtime"
    end
  end

  def check_unit_availability
    total_quantity = AvailabilityStore.get_total_quantity(@variant_stock.id)
    if total_quantity.nil?
      AvailabilityStore.initialize_from_db(@variant_stock)
      total_quantity = @variant_stock.quantity
    end

    available_quantity = AvailabilityStore.get_available_quantity(@variant_stock.id) || total_quantity

    if available_quantity < @requested_quantity
      variant_name = get_variant_stock_name(@variant_stock)
      raise OrderOverlapError, "Insufficient availability for #{variant_name}. Only #{available_quantity} available, but #{@requested_quantity} requested."
    end

    available_quantity
  end

  def check_bulk_availability
    total_quantity = AvailabilityStore.get_total_quantity(@variant_stock.id)
    if total_quantity.nil?
      AvailabilityStore.initialize_from_db(@variant_stock)
      total_quantity = @variant_stock.quantity
    end

    available_quantity = AvailabilityStore.get_available_quantity(@variant_stock.id) || total_quantity

    if available_quantity < @requested_quantity
      variant_name = get_variant_stock_name(@variant_stock)
      raise OrderOverlapError, "Capacity exceeded for #{variant_name}. Only #{available_quantity} available, but #{@requested_quantity} requested."
    end

    available_quantity
  end

  def validate_availability
    validate_time_range
    check_downtime_overlap

    if @product.unit?
      check_unit_availability
    elsif @product.bulk?
      check_bulk_availability
    else
      raise TimeRangeInvalidError, "Invalid bookable_type for product #{@product.id}"
    end
  end

  private

  def get_variant_stock_name(variant_stock)
    return "this item" if variant_stock.option_ids.empty?

    variant_options = variant_stock.variant_options.includes(:variant_type)
    return "this item" if variant_options.empty?

    variant_options_by_type = variant_options.group_by { |opt| opt.variant_type_id }

    names = variant_options_by_type.map do |variant_type_id, options|
      variant_type = options.first.variant_type
      option_names = options.map(&:name).join(", ")
      "#{variant_type.name} - #{option_names}"
    end

    names.join(" / ")
  end
end
