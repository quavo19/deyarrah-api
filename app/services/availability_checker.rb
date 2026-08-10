class AvailabilityChecker
  class AvailabilityConflictError < StandardError; end
  class DowntimeConflictError < StandardError; end
  class RedisUnavailableError < StandardError; end

  def initialize(variant_stock, start_at, end_at)
    @variant_stock = variant_stock
    @start_at = start_at
    @end_at = end_at
  end

  def available_quantity
    ensure_redis_initialized
    
    downtime = AvailabilityStore.get_downtime_flag(@variant_stock.id)
    if downtime
      return 0
    end

    AvailabilityStore.get_available_quantity(@variant_stock.id) || 0
  end

  def check_downtime_overlap
    ensure_redis_initialized
    
    if AvailabilityStore.get_downtime_flag(@variant_stock.id)
      raise DowntimeConflictError, "Variant stock #{@variant_stock.id} is in downtime"
    end

    overlapping_downtimes = @variant_stock.downtimes
      .where("start_at < ? AND end_at > ?", @end_at, @start_at)
      .where(ended_at: nil)

    if overlapping_downtimes.exists?
      raise DowntimeConflictError, "Variant stock #{@variant_stock.id} has overlapping downtime"
    end
  end

  def check_availability(requested_quantity)
    ensure_redis_initialized
    check_downtime_overlap

    available = AvailabilityStore.get_available_quantity(@variant_stock.id)
    
    if available.nil?
      raise AvailabilityConflictError, "Variant stock #{@variant_stock.id} not initialized in Redis"
    end

    if available < requested_quantity
      raise AvailabilityConflictError, "Insufficient availability for variant stock #{@variant_stock.id}. Available: #{available}, Requested: #{requested_quantity}"
    end

    available
  end

  private

  def ensure_redis_initialized
    total = AvailabilityStore.get_total_quantity(@variant_stock.id)
    if total.nil?
      AvailabilityStore.initialize_from_db(@variant_stock)
    end
  end
end
