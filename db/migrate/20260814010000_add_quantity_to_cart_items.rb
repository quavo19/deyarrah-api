class AddQuantityToCartItems < ActiveRecord::Migration[8.0]
  def change
    add_column :cart_items, :quantity, :integer, null: false, default: 1 unless column_exists?(:cart_items, :quantity)
    add_check_constraint :cart_items, "quantity > 0", name: "cart_items_quantity_positive" unless check_constraint_exists?(:cart_items, name: "cart_items_quantity_positive")
  end
end
