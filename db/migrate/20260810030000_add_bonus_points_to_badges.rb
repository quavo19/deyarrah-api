class AddBonusPointsToBadges < ActiveRecord::Migration[8.0]
  def change
    add_column :badges, :bonus_points, :integer, default: 0, null: false unless column_exists?(:badges, :bonus_points)
    add_check_constraint :badges, "bonus_points >= 0", name: "badges_bonus_points_non_negative" unless check_constraint_exists?(:badges, name: "badges_bonus_points_non_negative")
  end
end
