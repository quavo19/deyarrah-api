class AddAddressToWarehouses < ActiveRecord::Migration[8.0]
  def change
    add_column :warehouses, :address, :jsonb, default: {}
    add_index :warehouses, :address, using: :gin
  end
end
