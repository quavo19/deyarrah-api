class CreateVariantTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :variant_types, id: :uuid do |t|
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
  end
end
