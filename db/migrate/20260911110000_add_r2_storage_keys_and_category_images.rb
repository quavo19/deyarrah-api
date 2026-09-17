class AddR2StorageKeysAndCategoryImages < ActiveRecord::Migration[7.1]
  def change
    add_column :images, :storage_key, :string
    add_index :images, :storage_key

    add_column :categories, :image_url, :string
    add_column :categories, :image_storage_key, :string
    add_index :categories, :image_storage_key

    add_column :sub_categories, :image_url, :string
    add_column :sub_categories, :image_storage_key, :string
    add_index :sub_categories, :image_storage_key

    add_column :users, :avatar_storage_key, :string
    add_index :users, :avatar_storage_key
  end
end
