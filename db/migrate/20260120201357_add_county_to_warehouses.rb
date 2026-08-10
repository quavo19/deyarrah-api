class AddCountyToWarehouses < ActiveRecord::Migration[8.0]
  def change
    add_column :warehouses, :county, :string
    add_index :warehouses, :county
  end
end
