class CreateFulfillments < ActiveRecord::Migration[8.0]
  def change
    create_table :fulfillments, id: :uuid do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.references :warehouse, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: 'pending'
      t.datetime :delivery_date
      t.decimal :delivery_fee, precision: 10, scale: 2

      t.timestamps
    end

    add_index :fulfillments, :status
    add_index :fulfillments, :delivery_date
  end
end
