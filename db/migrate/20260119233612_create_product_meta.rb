class CreateProductMeta < ActiveRecord::Migration[8.0]
  def change
    create_table :product_meta, id: :uuid do |t|
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :value, null: false

      t.timestamps
    end

    add_index :product_meta, [ :product_id, :name ]
  end
end
