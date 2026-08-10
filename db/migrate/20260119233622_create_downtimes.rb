class CreateDowntimes < ActiveRecord::Migration[8.0]
  def change
    create_table :downtimes, id: :uuid do |t|
      t.references :variant_stock, null: false, foreign_key: true, type: :uuid
      t.datetime :start_at, null: false
      t.datetime :end_at, null: false
      t.datetime :ended_at
      t.text :reason

      t.timestamps
    end

    add_index :downtimes, :start_at
    add_index :downtimes, :end_at
  end
end
