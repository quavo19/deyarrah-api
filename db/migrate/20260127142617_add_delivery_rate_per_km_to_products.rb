class AddDeliveryRatePerKmToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :delivery_rate_per_km, :decimal, precision: 10, scale: 2, default: 10.0, null: false
  end
end
