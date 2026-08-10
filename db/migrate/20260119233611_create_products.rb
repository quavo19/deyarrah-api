class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.string :bookable_type, null: false
      t.boolean :active, default: true, null: false
      t.string :category

      t.timestamps
    end

    add_index :products, :bookable_type
    add_index :products, :active
  end
end
