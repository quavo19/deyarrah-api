class DowntimeStartJob < ApplicationJob
  sidekiq_options queue: :default

  def perform(downtime_id)
    downtime = Downtime.find_by(id: downtime_id)
    return unless downtime

    if downtime.ended_at.present?
      return
    end

    if downtime.start_at > Time.current
      return
    end

    variant_stock = downtime.variant_stock
    return unless variant_stock

    # Ensure Redis is initialized (handles Redis restarts)
    total_quantity = AvailabilityStore.get_total_quantity(variant_stock.id)
    if total_quantity.nil?
      AvailabilityStore.initialize_from_db(variant_stock)
    end

    AvailabilityStore.toggle_downtime_on(variant_stock.id)
    AvailabilityStore.set_reserved_quantity(variant_stock.id, 0)
    
    # Update product status
    variant_stock.product&.update_status
  end
end
