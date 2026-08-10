class AddGeocodingMetadataToWarehouses < ActiveRecord::Migration[8.0]
  def change
    add_column :warehouses, :country, :string
    add_column :warehouses, :region, :string
    add_column :warehouses, :city, :string

    add_index :warehouses, :country
    add_index :warehouses, :region
    add_index :warehouses, :city
  end
end
