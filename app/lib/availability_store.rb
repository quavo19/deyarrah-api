require "redis"
require "securerandom"

module AvailabilityStore
  REDIS_KEY_PREFIX = "variant_stock"
  LOCK_TIMEOUT = 30

  class << self
    def redis
      @redis ||= begin
        Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
      rescue StandardError => e
        raise RedisUnavailableError, "Redis connection failed: #{e.message}"
      end
    end

    def total_quantity_key(variant_stock_id)
      "#{REDIS_KEY_PREFIX}:#{variant_stock_id}:total_quantity"
    end

    def reserved_quantity_key(variant_stock_id)
      "#{REDIS_KEY_PREFIX}:#{variant_stock_id}:reserved_quantity"
    end

    def downtime_key(variant_stock_id)
      "#{REDIS_KEY_PREFIX}:#{variant_stock_id}:downtime"
    end

    def lock_key(variant_stock_id)
      "#{REDIS_KEY_PREFIX}:#{variant_stock_id}:lock"
    end

    def initialize_from_db(variant_stock)
      redis.set(total_quantity_key(variant_stock.id), variant_stock.quantity)
      redis.set(reserved_quantity_key(variant_stock.id), 0)
      redis.set(downtime_key(variant_stock.id), "false")
    end

    def get_total_quantity(variant_stock_id)
      value = redis.get(total_quantity_key(variant_stock_id))
      value ? value.to_i : nil
    end

    def get_reserved_quantity(variant_stock_id)
      value = redis.get(reserved_quantity_key(variant_stock_id))
      value ? value.to_i : 0
    end

    def get_available_quantity(variant_stock_id)
      total = get_total_quantity(variant_stock_id)
      return nil unless total
      reserved = get_reserved_quantity(variant_stock_id)
      total - reserved
    end

    def get_downtime_flag(variant_stock_id)
      value = redis.get(downtime_key(variant_stock_id))
      value == "true"
    end

    def atomic_check_and_reserve(variant_stock_id, quantity)
      script = <<-LUA
        local total_key = KEYS[1]
        local reserved_key = KEYS[2]
        local downtime_key = KEYS[3]
        local requested = tonumber(ARGV[1])
        
        local total = redis.call('GET', total_key)
        if not total then
          return {err = 'not_initialized'}
        end
        total = tonumber(total)
        
        local downtime = redis.call('GET', downtime_key)
        if downtime == "true" then
          return {err = 'downtime'}
        end
        
        local reserved = redis.call('GET', reserved_key)
        reserved = reserved and tonumber(reserved) or 0
        
        local available = total - reserved
        if available < requested then
          return {err = 'insufficient', available = available}
        end
        
        local new_reserved = reserved + requested
        redis.call('SET', reserved_key, new_reserved)
        return {ok = new_reserved}
      LUA

      result = redis.eval(
        script,
        [total_quantity_key(variant_stock_id), reserved_quantity_key(variant_stock_id), downtime_key(variant_stock_id)],
        [quantity]
      )

      if result.is_a?(Array) && result[0] == "err"
        case result[1]
        when "not_initialized"
          raise AvailabilityError, "Variant stock #{variant_stock_id} not initialized in Redis"
        when "downtime"
          raise DowntimeConflictError, "Variant stock #{variant_stock_id} is in downtime"
        when "insufficient"
          raise InsufficientAvailabilityError.new(result[2])
        end
      end

      result[1]
    end

    def atomic_multi_reserve(reservations)
      script = <<-LUA
        local reservations = {}
        local reservation_index = 1
        
        for i = 1, #KEYS, 3 do
          local total_key = KEYS[i]
          local reserved_key = KEYS[i + 1]
          local downtime_key = KEYS[i + 2]
          local requested = tonumber(ARGV[reservation_index])
          
          local total = redis.call('GET', total_key)
          if not total then
            return {err = 'not_initialized', index = reservation_index}
          end
          total = tonumber(total)
          
          local downtime = redis.call('GET', downtime_key)
          if downtime == "true" then
            return {err = 'downtime', index = reservation_index}
          end
          
          local reserved = redis.call('GET', reserved_key)
          reserved = reserved and tonumber(reserved) or 0
          
          local available = total - reserved
          if available < requested then
            return {err = 'insufficient', available = available, index = reservation_index}
          end
          
          table.insert(reservations, {reserved_key = reserved_key, requested = requested, current_reserved = reserved})
          reservation_index = reservation_index + 1
        end
        
        for _, res in ipairs(reservations) do
          local new_reserved = res.current_reserved + res.requested
          redis.call('SET', res.reserved_key, new_reserved)
        end
        
        return {ok = true}
      LUA

      keys = []
      args = []
      reservations.each do |res|
        keys << total_quantity_key(res[:variant_stock_id])
        keys << reserved_quantity_key(res[:variant_stock_id])
        keys << downtime_key(res[:variant_stock_id])
        args << res[:quantity]
      end

      result = redis.eval(script, keys, args)

      if result.is_a?(Array) && result[0] == "err"
        index = result[3] || 0
        variant_stock_id = reservations[index - 1][:variant_stock_id] if index > 0 && index <= reservations.length
        case result[1]
        when "not_initialized"
          raise AvailabilityError, "Variant stock #{variant_stock_id} not initialized in Redis"
        when "downtime"
          raise DowntimeConflictError, "Variant stock #{variant_stock_id} is in downtime"
        when "insufficient"
          raise InsufficientAvailabilityError.new(result[2])
        end
      end
    end

    def atomic_restore(variant_stock_id, quantity)
      script = <<-LUA
        local reserved_key = KEYS[1]
        local to_restore = tonumber(ARGV[1])
        
        local reserved = redis.call('GET', reserved_key)
        if not reserved then
          return {err = 'not_initialized'}
        end
        reserved = tonumber(reserved)
        
        local new_reserved = math.max(0, reserved - to_restore)
        redis.call('SET', reserved_key, new_reserved)
        return {ok = new_reserved}
      LUA

      result = redis.eval(script, [reserved_quantity_key(variant_stock_id)], [quantity])

      if result.is_a?(Array) && result[0] == "err"
        raise AvailabilityError, "Variant stock #{variant_stock_id} not initialized in Redis"
      end

      result[1]
    end

    def atomic_multi_restore(restorations)
      script = <<-LUA
        for i = 1, #KEYS do
          local reserved_key = KEYS[i]
          local to_restore = tonumber(ARGV[i])
          
          local reserved = redis.call('GET', reserved_key)
          if reserved then
            reserved = tonumber(reserved)
            local new_reserved = math.max(0, reserved - to_restore)
            redis.call('SET', reserved_key, new_reserved)
          end
        end
        return {ok = true}
      LUA

      keys = restorations.map { |r| reserved_quantity_key(r[:variant_stock_id]) }
      args = restorations.map { |r| r[:quantity] }

      redis.eval(script, keys, args)
    end

    def set_downtime_flag(variant_stock_id, value)
      redis.set(downtime_key(variant_stock_id), value ? "true" : "false")
    end

    def toggle_downtime_on(variant_stock_id)
      set_downtime_flag(variant_stock_id, true)
    end

    def toggle_downtime_off(variant_stock_id)
      set_downtime_flag(variant_stock_id, false)
    end

    def set_total_quantity(variant_stock_id, quantity)
      redis.set(total_quantity_key(variant_stock_id), quantity)
    end

    def set_reserved_quantity(variant_stock_id, quantity)
      redis.set(reserved_quantity_key(variant_stock_id), quantity)
    end

    def lock(variant_stock_id)
      lock_script = <<-LUA
        local lock_key = KEYS[1]
        local timeout = tonumber(ARGV[1])
        local lock_value = ARGV[2]
        
        local existing = redis.call('GET', lock_key)
        if existing then
          return {err = 'locked'}
        end
        
        redis.call('SET', lock_key, lock_value, 'EX', timeout)
        return {ok = true}
      LUA

      lock_value = SecureRandom.uuid
      result = redis.eval(lock_script, [lock_key(variant_stock_id)], [LOCK_TIMEOUT, lock_value])
      
      if result.is_a?(Array) && result[0] == "err"
        raise LockError, "Variant stock #{variant_stock_id} is currently locked"
      end
      
      lock_value
    end

    def unlock(variant_stock_id, lock_value)
      unlock_script = <<-LUA
        local lock_key = KEYS[1]
        local expected_value = ARGV[1]
        
        local current = redis.call('GET', lock_key)
        if current == expected_value then
          redis.call('DEL', lock_key)
          return {ok = true}
        end
        return {err = 'mismatch'}
      LUA

      result = redis.eval(unlock_script, [lock_key(variant_stock_id)], [lock_value])
      
      if result.is_a?(Array) && result[0] == "err"
        raise LockError, "Lock mismatch for variant stock #{variant_stock_id}"
      end
    end

    def initialize_all
      VariantStock.find_each do |variant_stock|
        initialize_from_db(variant_stock)
      end
    end
  end

  class AvailabilityError < StandardError; end
  class InsufficientAvailabilityError < StandardError
    attr_reader :available_quantity

    def initialize(available_quantity)
      @available_quantity = available_quantity
      super("Insufficient availability. Available: #{available_quantity}")
    end
  end
  class LockError < StandardError; end
  class RedisUnavailableError < StandardError; end
  class DowntimeConflictError < StandardError; end
end
