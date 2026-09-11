class CreateCartAndWishlistItems < ActiveRecord::Migration[8.0]
  def change
    create_table :cart_items, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :product, null: false, type: :uuid, foreign_key: true
      t.timestamps
    end

    add_index :cart_items, [ :user_id, :product_id ], unique: true

    create_table :wishlist_items, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :product, null: false, type: :uuid, foreign_key: true
      t.timestamps
    end

    add_index :wishlist_items, [ :user_id, :product_id ], unique: true
  end
end
