class AddSubCategoriesAndProductCategoryJoins < ActiveRecord::Migration[8.0]
  def up
    create_table :sub_categories, id: :uuid do |t|
      t.references :category, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.timestamps
    end unless table_exists?(:sub_categories)

    add_index :sub_categories, [ :category_id, :name ], unique: true unless index_exists?(:sub_categories, [ :category_id, :name ], unique: true)

    create_table :product_categories, id: :uuid do |t|
      t.references :product, null: false, type: :uuid, foreign_key: true
      t.references :category, null: false, type: :uuid, foreign_key: true
      t.timestamps
    end unless table_exists?(:product_categories)

    add_index :product_categories, [ :product_id, :category_id ], unique: true unless index_exists?(:product_categories, [ :product_id, :category_id ], unique: true)

    create_table :product_sub_categories, id: :uuid do |t|
      t.references :product, null: false, type: :uuid, foreign_key: true
      t.references :sub_category, null: false, type: :uuid, foreign_key: true
      t.timestamps
    end unless table_exists?(:product_sub_categories)

    add_index :product_sub_categories, [ :product_id, :sub_category_id ], unique: true unless index_exists?(:product_sub_categories, [ :product_id, :sub_category_id ], unique: true)

    execute <<~SQL.squish
      INSERT INTO product_categories (id, product_id, category_id, created_at, updated_at)
      SELECT gen_random_uuid(), products.id, products.category_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM products
      LEFT JOIN product_categories
        ON product_categories.product_id = products.id
       AND product_categories.category_id = products.category_id
      WHERE products.category_id IS NOT NULL
        AND product_categories.id IS NULL
    SQL
  end

  def down
    drop_table :product_sub_categories if table_exists?(:product_sub_categories)
    drop_table :product_categories if table_exists?(:product_categories)
    drop_table :sub_categories if table_exists?(:sub_categories)
  end
end
