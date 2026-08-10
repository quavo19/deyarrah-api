class CreateCustomerAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :customer_addresses, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.string :country
      t.string :region
      t.string :city
      t.string :county
      t.jsonb :address, default: {}
      t.boolean :is_default, default: false, null: false

      t.timestamps
    end

    # Note: user_id index is automatically created by t.references
    add_index :customer_addresses, :name
    add_index :customer_addresses, [:latitude, :longitude]
    add_index :customer_addresses, :is_default
    add_index :customer_addresses, :address, using: :gin
  end
end
