class CreateImages < ActiveRecord::Migration[8.0]
  def change
    create_table :images, id: :uuid do |t|
      t.references :owner, polymorphic: true, null: false, type: :uuid
      t.string :url, null: false

      t.timestamps
    end

    add_index :images, [ :owner_type, :owner_id ]
  end
end
