class DowntimeEndJob < ApplicationJob
  sidekiq_options queue: :default

  def perform(downtime_id)
    downtime = Downtime.find_by(id: downtime_id)
    return unless downtime

    if downtime.ended_at.present?
      return
    end

    if downtime.end_at > Time.current
      return
    end

    variant_stock = downtime.variant_stock
    return unless variant_stock

    # Ensure Redis is initialized (handles Redis restarts)
    total_quantity = AvailabilityStore.get_total_quantity(variant_stock.id)
    if total_quantity.nil?
      AvailabilityStore.initialize_from_db(variant_stock)
    end

    # Reconcile reserved quantity from database after downtime ends
    db_reserved_quantity = Order.active
      .joins(:order_items)
      .where(order_items: { variant_stock_id: variant_stock.id })
      .sum("order_items.quantity")

    AvailabilityStore.toggle_downtime_off(variant_stock.id)
    AvailabilityStore.set_reserved_quantity(variant_stock.id, db_reserved_quantity)
    
    # Update product status
    variant_stock.product&.update_status
  end
end
