class AddPhonesToBookings < ActiveRecord::Migration[8.0]
  def change
    # Store phone numbers as an array of strings
    add_column :bookings, :phones, :text, array: true, default: []
  end
end
