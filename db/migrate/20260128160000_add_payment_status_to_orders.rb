# frozen_string_literal: true

class AddPaymentStatusToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :payment_status, :string, null: false, default: "pending"
    add_index :orders, :payment_status
  end
end

