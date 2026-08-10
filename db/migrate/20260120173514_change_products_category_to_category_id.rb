class ChangeProductsCategoryToCategoryId < ActiveRecord::Migration[8.0]
  def up
    # Create categories from existing category strings
    execute <<-SQL
      INSERT INTO categories (id, name, created_at, updated_at)
      SELECT DISTINCT gen_random_uuid(), category, NOW(), NOW()
      FROM products
      WHERE category IS NOT NULL AND category != ''
      ON CONFLICT (name) DO NOTHING;
    SQL

    # Add category_id column
    add_reference :products, :category, null: true, foreign_key: true, type: :uuid

    # Migrate data: link products to categories
    execute <<-SQL
      UPDATE products
      SET category_id = categories.id
      FROM categories
      WHERE products.category = categories.name;
    SQL

    # Remove old category column
    remove_column :products, :category, :string
  end

  def down
    # Add back category column
    add_column :products, :category, :string

    # Migrate data back
    execute <<-SQL
      UPDATE products
      SET category = categories.name
      FROM categories
      WHERE products.category_id = categories.id;
    SQL

    # Remove category_id column
    remove_reference :products, :category, foreign_key: true, type: :uuid
  end
end
