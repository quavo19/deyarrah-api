class ExtendTransactionsForPaymentLedger < ActiveRecord::Migration[8.0]
  def up
    add_reference :transactions, :user, type: :uuid, foreign_key: true, index: true
    add_reference :transactions, :affiliate_withdrawal, type: :uuid, foreign_key: true, index: true
    add_column :transactions, :purpose, :string, null: false, default: "order_payment"
    add_column :transactions, :direction, :string, null: false, default: "credit"
    add_column :transactions, :processed_at, :datetime

    execute <<~SQL.squish
      UPDATE transactions
      SET user_id = orders.user_id
      FROM orders
      WHERE transactions.order_id = orders.id
    SQL

    change_column_null :transactions, :order_id, true

    add_index :transactions, :purpose
    add_index :transactions, :direction
    add_index :transactions, :processed_at
    add_index :transactions,
      :affiliate_withdrawal_id,
      unique: true,
      where: "affiliate_withdrawal_id IS NOT NULL",
      name: "idx_transactions_unique_affiliate_withdrawal"

    add_check_constraint :transactions,
      "purpose IN ('order_payment', 'affiliate_withdrawal_payout')",
      name: "transactions_purpose_valid"
    add_check_constraint :transactions,
      "direction IN ('credit', 'debit')",
      name: "transactions_direction_valid"
    add_check_constraint :transactions,
      "order_id IS NOT NULL OR affiliate_withdrawal_id IS NOT NULL",
      name: "transactions_reference_present"
  end

  def down
    remove_check_constraint :transactions, name: "transactions_reference_present"
    remove_check_constraint :transactions, name: "transactions_direction_valid"
    remove_check_constraint :transactions, name: "transactions_purpose_valid"
    remove_index :transactions, name: "idx_transactions_unique_affiliate_withdrawal"
    remove_index :transactions, :processed_at
    remove_index :transactions, :direction
    remove_index :transactions, :purpose

    change_column_null :transactions, :order_id, false

    remove_column :transactions, :processed_at
    remove_column :transactions, :direction
    remove_column :transactions, :purpose
    remove_reference :transactions, :affiliate_withdrawal, foreign_key: true
    remove_reference :transactions, :user, foreign_key: true
  end
end
