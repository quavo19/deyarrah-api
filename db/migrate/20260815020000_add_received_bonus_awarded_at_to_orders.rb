class AddReceivedBonusAwardedAtToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :received_bonus_awarded_at, :datetime unless column_exists?(:orders, :received_bonus_awarded_at)
  end
end
