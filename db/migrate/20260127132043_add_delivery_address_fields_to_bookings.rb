class AddDeliveryAddressFieldsToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :delivery_address_name, :string
    add_column :bookings, :delivery_latitude, :decimal, precision: 10, scale: 7
    add_column :bookings, :delivery_longitude, :decimal, precision: 10, scale: 7
  end
end
