class CreateBookings < ActiveRecord::Migration[8.0]
  def change
    create_table :bookings, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.datetime :start_at, null: false
      t.datetime :end_at, null: false
      t.string :status, null: false

      t.timestamps
    end

    add_index :bookings, :start_at
    add_index :bookings, :end_at
    add_index :bookings, :status
  end
end
