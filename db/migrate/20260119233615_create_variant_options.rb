class CreateVariantOptions < ActiveRecord::Migration[8.0]
  def change
    create_table :variant_options, id: :uuid do |t|
      t.references :variant_type, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2, default: 0.0, null: false

      t.timestamps
    end

  end
end
