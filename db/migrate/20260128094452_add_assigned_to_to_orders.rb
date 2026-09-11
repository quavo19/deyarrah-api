class AddAssignedToToOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :assigned_to, type: :uuid, foreign_key: { to_table: :users }, index: true
  end
end
