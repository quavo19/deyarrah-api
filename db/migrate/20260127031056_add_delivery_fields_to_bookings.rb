class AddDeliveryFieldsToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :delivery_distance, :decimal, precision: 10, scale: 2, default: 0.0, null: false
    add_column :bookings, :delivery_fee, :decimal, precision: 10, scale: 2, default: 0.0, null: false
    add_column :bookings, :item_subtotal, :decimal, precision: 10, scale: 2, default: 0.0, null: false
    add_column :bookings, :total_amount, :decimal, precision: 10, scale: 2, default: 0.0, null: false
  end
end
