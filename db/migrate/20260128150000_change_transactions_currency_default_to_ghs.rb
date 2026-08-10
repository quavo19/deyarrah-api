# frozen_string_literal: true

class ChangeTransactionsCurrencyDefaultToGhs < ActiveRecord::Migration[8.0]
  def change
    change_column_default :transactions, :currency, from: "NGN", to: "GHS"
  end
end
