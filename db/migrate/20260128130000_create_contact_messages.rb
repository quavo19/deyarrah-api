class CreateContactMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :contact_messages, id: :uuid do |t|
      t.string :purpose, null: false
      t.text :message, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone, null: false

      t.timestamps
    end

    add_index :contact_messages, :email
    add_index :contact_messages, :name
    add_index :contact_messages, :phone
    add_index :contact_messages, :created_at
  end
end
