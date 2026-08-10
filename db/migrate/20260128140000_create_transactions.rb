class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions, id: :uuid do |t|
      t.references :booking, null: false, foreign_key: true, type: :uuid
      t.integer :amount_kobo, null: false
      t.string :currency, null: false, default: "NGN"
      t.string :status, null: false, default: "initialized"
      t.string :provider, null: false, default: "paystack"
      t.string :provider_reference, null: false
      t.jsonb :metadata

      t.timestamps
    end

    add_index :transactions, :provider_reference, unique: true
    add_index :transactions, :status
  end
end
