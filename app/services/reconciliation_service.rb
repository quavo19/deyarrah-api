class ReconciliationService
  def initialize(variant_stock_id = nil)
    @variant_stock_id = variant_stock_id
  end

  def reconcile_all
    scope = @variant_stock_id ? VariantStock.where(id: @variant_stock_id) : VariantStock.all
    
    scope.find_each do |variant_stock|
      reconcile_variant_stock(variant_stock)
    end
  end

  def reconcile_variant_stock(variant_stock)
    AvailabilityStore.set_total_quantity(variant_stock.id, variant_stock.quantity)
    
    reserved_quantity = calculate_reserved_quantity(variant_stock)
    AvailabilityStore.set_reserved_quantity(variant_stock.id, reserved_quantity)
    
    downtime_active = variant_stock.downtime_active?
    AvailabilityStore.set_downtime_flag(variant_stock.id, downtime_active)
  end

  private

  def calculate_reserved_quantity(variant_stock)
    Order.active
      .joins(:order_items)
      .where(order_items: { variant_stock_id: variant_stock.id })
      .sum("order_items.quantity")
  end
end
