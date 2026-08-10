class AddWarehouseCoordinatesToFulfillments < ActiveRecord::Migration[8.0]
  def change
    add_column :fulfillments, :warehouse_latitude, :decimal, precision: 10, scale: 7
    add_column :fulfillments, :warehouse_longitude, :decimal, precision: 10, scale: 7
  end
end
