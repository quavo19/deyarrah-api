class AddDeliveryAddressFieldsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :delivery_address_name, :string
    add_column :orders, :delivery_latitude, :decimal, precision: 10, scale: 7
    add_column :orders, :delivery_longitude, :decimal, precision: 10, scale: 7
  end
end
