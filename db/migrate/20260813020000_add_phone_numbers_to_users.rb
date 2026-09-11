class AddPhoneNumbersToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :phone_numbers, :text, array: true, default: [], null: false unless column_exists?(:users, :phone_numbers)
  end
end
