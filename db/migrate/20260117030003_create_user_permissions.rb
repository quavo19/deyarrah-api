class CreateUserPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_permissions, id: :uuid do |t|
      # Initially use integer for user_id, will be updated in later migration
      t.integer :user_id, null: false
      t.references :permission, null: false, foreign_key: true, type: :uuid
      t.timestamps
    end

    add_index :user_permissions, [ :user_id, :permission_id ], unique: true
    # Foreign key will be added after users table is migrated to UUID
  end
end
