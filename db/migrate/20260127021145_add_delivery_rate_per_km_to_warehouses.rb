class AddDeliveryRatePerKmToWarehouses < ActiveRecord::Migration[8.0]
  def change
    add_column :warehouses, :delivery_rate_per_km, :decimal, precision: 10, scale: 2, default: 50.0, null: false
  end
end
