class AddWarehouseIdToVariantStocks < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Add column as nullable first
    add_reference :variant_stocks, :warehouse, null: true, foreign_key: true, type: :uuid, index: true

    # Step 2: Handle existing variant_stocks without warehouse_id
    # Delete dependent records first to avoid foreign key violations
    execute <<-SQL
      DELETE FROM booking_items 
      WHERE variant_stock_id IN (SELECT id FROM variant_stocks WHERE warehouse_id IS NULL);
    SQL
    
    execute <<-SQL
      DELETE FROM downtimes 
      WHERE variant_stock_id IN (SELECT id FROM variant_stocks WHERE warehouse_id IS NULL);
    SQL

    # Now delete variant_stocks without warehouse_id
    # Note: If you want to preserve data, uncomment and modify the code below:
    # default_warehouse = execute("SELECT id FROM warehouses LIMIT 1").first
    # if default_warehouse
    #   warehouse_id = default_warehouse['id']
    #   execute "UPDATE variant_stocks SET warehouse_id = '#{warehouse_id}' WHERE warehouse_id IS NULL"
    # else
    #   raise "No warehouses exist. Please create at least one warehouse before running this migration."
    # end
    execute "DELETE FROM variant_stocks WHERE warehouse_id IS NULL"

    # Step 3: Make column non-nullable
    change_column_null :variant_stocks, :warehouse_id, false
  end

  def down
    remove_reference :variant_stocks, :warehouse, foreign_key: true, type: :uuid
  end
end
