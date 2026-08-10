class CreateWarehouses < ActiveRecord::Migration[8.0]
  def change
    create_table :warehouses, id: :uuid do |t|
      t.string :name, null: false
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false

      t.timestamps
    end

    add_index :warehouses, :name
    add_index :warehouses, [:latitude, :longitude]
  end
end
