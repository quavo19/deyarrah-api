class AddVariantStockSnapshotToBookingItems < ActiveRecord::Migration[8.0]
  def change
    add_column :booking_items, :variant_stock_price, :decimal, precision: 10, scale: 2
    add_column :booking_items, :variant_stock_quantity, :integer
    add_column :booking_items, :variant_stock_option_names, :text
    add_column :booking_items, :variant_stock_warehouse_name, :string
    add_column :booking_items, :variant_stock_warehouse_address, :jsonb, default: {}
    add_column :booking_items, :variant_stock_warehouse_latitude, :decimal, precision: 10, scale: 7
    add_column :booking_items, :variant_stock_warehouse_longitude, :decimal, precision: 10, scale: 7
    add_column :booking_items, :variant_stock_warehouse_country, :string
    add_column :booking_items, :variant_stock_warehouse_region, :string
    add_column :booking_items, :variant_stock_warehouse_city, :string
    add_column :booking_items, :variant_stock_warehouse_county, :string
  end
end
