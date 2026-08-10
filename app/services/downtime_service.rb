class DowntimeService
  class DowntimeConflictError < StandardError; end
  class BookingConflictError < StandardError; end
  class ValidationError < StandardError; end

  def initialize(downtime = nil)
    @downtime = downtime
  end

  def create(variant_stock, start_at, end_at, reason = nil)
    validate_time_range(start_at, end_at)
    check_overlapping_downtimes(variant_stock, start_at, end_at)
    check_conflicting_bookings(variant_stock, start_at, end_at)

    downtime = nil
    ActiveRecord::Base.transaction do
      downtime = Downtime.create!(
        variant_stock: variant_stock,
        start_at: start_at,
        end_at: end_at,
        reason: reason
      )

      ensure_redis_initialized(variant_stock)
      
      # Handle downtime start
      if downtime.start_at <= Time.current
        # If downtime period is completely in the past, don't activate it
        if downtime.end_at > Time.current
          AvailabilityStore.toggle_downtime_on(variant_stock.id)
          AvailabilityStore.set_reserved_quantity(variant_stock.id, 0)
        end
      else
        # Schedule start job for future
        DowntimeStartJob.set(wait_until: downtime.start_at).perform_later(downtime.id)
      end

      # Schedule end job if downtime hasn't ended yet
      if downtime.end_at > Time.current
        DowntimeEndJob.set(wait_until: downtime.end_at).perform_later(downtime.id)
      end
    end

    downtime
  end

  def update(start_at: nil, end_at: nil, reason: nil)
    raise ValidationError, "Downtime not set" unless @downtime

    new_start_at = start_at || @downtime.start_at
    new_end_at = end_at || @downtime.end_at

    validate_time_range(new_start_at, new_end_at)
    check_overlapping_downtimes(@downtime.variant_stock, new_start_at, new_end_at, exclude_id: @downtime.id)
    check_conflicting_bookings(@downtime.variant_stock, new_start_at, new_end_at)

    was_active = @downtime.active?
    old_start_at = @downtime.start_at
    old_end_at = @downtime.end_at

    ActiveRecord::Base.transaction do
      @downtime.update!(
        start_at: new_start_at,
        end_at: new_end_at,
        reason: reason || @downtime.reason
      )

      ensure_redis_initialized(@downtime.variant_stock)
      
      if was_active && !@downtime.active?
        AvailabilityStore.toggle_downtime_off(@downtime.variant_stock_id)
      elsif !was_active && @downtime.active?
        AvailabilityStore.toggle_downtime_on(@downtime.variant_stock_id)
        AvailabilityStore.set_reserved_quantity(@downtime.variant_stock_id, 0)
      end

      cancel_scheduled_jobs

      if new_start_at > Time.current
        DowntimeStartJob.set(wait_until: new_start_at).perform_later(@downtime.id)
      end

      if new_end_at > Time.current
        DowntimeEndJob.set(wait_until: new_end_at).perform_later(@downtime.id)
      end

      @downtime
    end
  end

  def end_early
    raise ValidationError, "Downtime not set" unless @downtime
    raise ValidationError, "Downtime already ended" if @downtime.ended?

    was_active = @downtime.active?

    ActiveRecord::Base.transaction do
      @downtime.update!(ended_at: Time.current)

      ensure_redis_initialized(@downtime.variant_stock)
      
      if was_active
        AvailabilityStore.toggle_downtime_off(@downtime.variant_stock_id)
      end

      cancel_scheduled_jobs

      @downtime
    end
  end

  def matches_downtime_job?(job, downtime_id)
    if job.klass == "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"
      job_args = job.args
      if job_args.is_a?(Array) && job_args.length >= 2
        job_class_name = job_args[0]
        job_data = job_args[1]
        if job_data.is_a?(Hash)
          arguments = job_data["arguments"] || []
          return (job_class_name == "DowntimeStartJob" || job_class_name == "DowntimeEndJob") && 
                 arguments.first == downtime_id
        end
      end
    else
      return (job.klass == "DowntimeStartJob" || job.klass == "DowntimeEndJob") && 
             job.args.first == downtime_id
    end
    false
  end

  private

  def validate_time_range(start_at, end_at)
    if start_at.blank? || end_at.blank?
      raise ValidationError, "start_at and end_at are required"
    end

    if end_at <= start_at
      raise ValidationError, "end_at must be after start_at"
    end
  end

  def check_overlapping_downtimes(variant_stock, start_at, end_at, exclude_id: nil)
    overlapping = variant_stock.downtimes.overlapping(start_at, end_at)
    overlapping = overlapping.where.not(id: exclude_id) if exclude_id

    if overlapping.exists?
      raise DowntimeConflictError, "Overlapping downtime already exists for this variant_stock"
    end
  end

  def check_conflicting_bookings(variant_stock, start_at, end_at)
    conflicting_bookings = Booking.confirmed
      .joins(:booking_items)
      .where(booking_items: { variant_stock_id: variant_stock.id })
      .overlapping(start_at, end_at)

    if conflicting_bookings.exists?
      raise BookingConflictError, "Cannot create downtime: conflicting confirmed bookings exist"
    end
  end

  def ensure_redis_initialized(variant_stock)
    total = AvailabilityStore.get_total_quantity(variant_stock.id)
    if total.nil?
      AvailabilityStore.initialize_from_db(variant_stock)
    end
  end

  def cancel_scheduled_jobs
    return unless @downtime

    Sidekiq::ScheduledSet.new.select do |job|
      matches_downtime_job?(job, @downtime.id)
    end.each(&:delete)
  end
end
