class AddAssignedToToBookings < ActiveRecord::Migration[8.0]
  def change
    add_reference :bookings, :assigned_to, type: :uuid, foreign_key: { to_table: :users }, index: true
  end
end
