class AddVariantStockToCartItems < ActiveRecord::Migration[8.0]
  def change
    add_reference :cart_items, :variant_stock, type: :uuid, foreign_key: true, index: true unless column_exists?(:cart_items, :variant_stock_id)

    if index_exists?(:cart_items, [ :user_id, :product_id ], name: "index_cart_items_on_user_id_and_product_id")
      remove_index :cart_items, name: "index_cart_items_on_user_id_and_product_id"
    end

    add_index :cart_items, [ :user_id, :product_id, :variant_stock_id ], unique: true, name: "index_cart_items_on_user_product_variant" unless index_exists?(:cart_items, [ :user_id, :product_id, :variant_stock_id ], name: "index_cart_items_on_user_product_variant")
    add_index :cart_items, [ :user_id, :product_id ], unique: true, where: "variant_stock_id IS NULL", name: "index_cart_items_on_user_product_without_variant" unless index_exists?(:cart_items, [ :user_id, :product_id ], name: "index_cart_items_on_user_product_without_variant")
  end
end
