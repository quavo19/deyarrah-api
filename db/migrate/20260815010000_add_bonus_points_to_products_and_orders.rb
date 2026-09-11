class AddBonusPointsToProductsAndOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :bonus_points, :integer, null: false, default: 0 unless column_exists?(:products, :bonus_points)
    add_check_constraint :products, "bonus_points >= 0", name: "products_bonus_points_non_negative" unless check_constraint_exists?(:products, name: "products_bonus_points_non_negative")

    add_column :orders, :bonus_points_awarded_at, :datetime unless column_exists?(:orders, :bonus_points_awarded_at)
  end
end
