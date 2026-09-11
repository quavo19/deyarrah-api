class AddPhonesToOrders < ActiveRecord::Migration[8.0]
  def change
    # Store phone numbers as an array of strings
    add_column :orders, :phones, :text, array: true, default: []
  end
end
