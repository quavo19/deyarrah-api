class CreateVariantStocks < ActiveRecord::Migration[8.0]
  def change
    create_table :variant_stocks, id: :uuid do |t|
      t.uuid :option_ids, array: true, default: [], null: false
      t.integer :quantity, null: false

      t.timestamps
    end

    add_index :variant_stocks, :option_ids, using: :gin
  end
end
