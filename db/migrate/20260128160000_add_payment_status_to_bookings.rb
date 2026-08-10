# frozen_string_literal: true

class AddPaymentStatusToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :payment_status, :string, null: false, default: "pending"
    add_index :bookings, :payment_status
  end
end

