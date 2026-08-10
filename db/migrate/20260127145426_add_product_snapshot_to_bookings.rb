class AddProductSnapshotToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :product_name, :string
    add_column :bookings, :product_description, :text
    add_column :bookings, :product_bookable_type, :string
    add_column :bookings, :product_delivery_rate_per_km, :decimal, precision: 10, scale: 2
  end
end
