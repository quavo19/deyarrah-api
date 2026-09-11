class AddProductIdToVariantStocks < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Add column as nullable first to preserve existing data
    add_reference :variant_stocks, :product, null: true, foreign_key: true, type: :uuid, index: true

    # Step 2: Populate product_id for existing variant stocks
    
    # For bulk products: get product from variant_options
    execute <<-SQL
      UPDATE variant_stocks
      SET product_id = (
        SELECT DISTINCT products.id
        FROM variant_options
        INNER JOIN variant_types ON variant_types.id = variant_options.variant_type_id
        INNER JOIN products ON products.id = variant_types.product_id
        WHERE variant_options.id = ANY(variant_stocks.option_ids)
        LIMIT 1
      )
      WHERE cardinality(option_ids) > 0
        AND product_id IS NULL;
    SQL

    # For unit products: get product from orders
    execute <<-SQL
      UPDATE variant_stocks
      SET product_id = (
        SELECT DISTINCT orders.product_id
        FROM order_items
        INNER JOIN orders ON orders.id = order_items.order_id
        WHERE order_items.variant_stock_id = variant_stocks.id
        LIMIT 1
      )
      WHERE (cardinality(option_ids) = 0 OR option_ids = '{}'::uuid[])
        AND product_id IS NULL;
    SQL

    # Step 3: For any remaining records without product_id, we'll leave them null
    # These are unit product stocks that have never been booked
    # They can be handled manually or deleted if needed
    
    # Step 4: Make product_id required for new records going forward
    # Note: We keep it nullable to preserve existing orphaned records
    # You can manually clean up orphaned records and then make it non-nullable if needed
  end

  def down
    remove_reference :variant_stocks, :product, foreign_key: true, type: :uuid
  end
end
