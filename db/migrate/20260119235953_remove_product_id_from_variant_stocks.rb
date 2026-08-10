class RemoveProductIdFromVariantStocks < ActiveRecord::Migration[8.0]
  def change
    # Only remove if the column exists (it may not have been created in the original migration)
    if column_exists?(:variant_stocks, :product_id)
      # Remove index if it exists
      remove_index :variant_stocks, :product_id if index_exists?(:variant_stocks, :product_id)
      
      # Remove foreign key if it exists (without raising error if it doesn't)
      begin
        remove_foreign_key :variant_stocks, :products
      rescue ArgumentError
        # Foreign key doesn't exist, which is fine
      end
      
      # Remove the column
      remove_column :variant_stocks, :product_id, :uuid
    end
  end
end
