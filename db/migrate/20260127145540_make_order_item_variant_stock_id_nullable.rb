class MakeOrderItemVariantStockIdNullable < ActiveRecord::Migration[8.0]
  def up
    # Remove foreign key constraint
    remove_foreign_key :order_items, :variant_stocks
    
    # Make column nullable
    change_column_null :order_items, :variant_stock_id, true
    
    # Re-add foreign key constraint with null allowed
    add_foreign_key :order_items, :variant_stocks, on_delete: :nullify
  end

  def down
    remove_foreign_key :order_items, :variant_stocks
    change_column_null :order_items, :variant_stock_id, false
    add_foreign_key :order_items, :variant_stocks
  end
end
