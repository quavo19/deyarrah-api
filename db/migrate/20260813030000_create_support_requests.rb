class CreateSupportRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :support_requests, id: :uuid do |t|
      t.references :user, type: :uuid, foreign_key: true, null: true
      t.string :topic, null: false
      t.text :message, null: false
      t.string :guest_full_name
      t.string :guest_email
      t.string :guest_phone

      t.timestamps
    end

    add_index :support_requests, :topic
    add_index :support_requests, :created_at
    add_index :support_requests, :guest_email
  end
end
