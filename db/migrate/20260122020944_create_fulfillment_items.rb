class CreateFulfillmentItems < ActiveRecord::Migration[8.0]
  def change
    create_table :fulfillment_items, id: :uuid do |t|
      t.references :fulfillment, null: false, foreign_key: true, type: :uuid
      t.references :order_item, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :fulfillment_items, [:fulfillment_id, :order_item_id], unique: true, name: 'index_fulfillment_items_on_fulfillment_and_order_item'
  end
end
