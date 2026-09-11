class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_items, id: :uuid do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.references :variant_stock, null: false, foreign_key: true, type: :uuid
      t.integer :quantity, null: false

      t.timestamps
    end

  end
end
