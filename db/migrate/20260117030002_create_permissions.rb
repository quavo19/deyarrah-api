class CreatePermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :permissions, id: :uuid do |t|
      t.string :name, null: false, index: { unique: true }
      t.timestamps
    end
  end
end
