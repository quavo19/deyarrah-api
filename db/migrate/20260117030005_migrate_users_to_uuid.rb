class MigrateUsersToUuid < ActiveRecord::Migration[8.0]
  def up
    # Create new users table with UUID
    create_table :users_new, id: :uuid do |t|
      t.string "email", default: "", null: false
      t.string "encrypted_password", default: "", null: false
      t.string "reset_password_token"
      t.datetime "reset_password_sent_at"
      t.datetime "remember_created_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "first_name"
      t.string "last_name"
      t.string "avatar"
      t.references :role, null: true, foreign_key: true, type: :uuid
      t.boolean "blocked", default: false, null: false
      t.boolean "otp_enabled", default: false, null: false
      t.string "otp_secret"
      t.datetime "otp_verified_at"
    end

    add_index :users_new, [ "email" ], name: "index_users_new_on_email", unique: true
    add_index :users_new, [ "reset_password_token" ], name: "index_users_new_on_reset_password_token", unique: true

    # Copy data from old table to new table (if any exists)
    execute <<-SQL
      INSERT INTO users_new (
        email, encrypted_password, reset_password_token, reset_password_sent_at,
        remember_created_at, created_at, updated_at, first_name, last_name, avatar,
        role_id, blocked, otp_enabled, otp_secret, otp_verified_at
      )
      SELECT#{' '}
        email, encrypted_password, reset_password_token, reset_password_sent_at,
        remember_created_at, created_at, updated_at, first_name, last_name, avatar,
        role_id, COALESCE(blocked, false), COALESCE(otp_enabled, false), otp_secret, otp_verified_at
      FROM users;
    SQL

    # Update user_permissions to reference new UUIDs
    # First, add a temporary uuid column
    add_column :user_permissions, :user_id_uuid, :uuid

    # Populate the uuid column
    execute <<-SQL
      UPDATE user_permissions up
      SET user_id_uuid = (
        SELECT un.id#{' '}
        FROM users_new un
        INNER JOIN users u ON u.email = un.email
        WHERE u.id = up.user_id::text::integer
      );
    SQL

    # Remove old column and rename new one
    remove_column :user_permissions, :user_id
    rename_column :user_permissions, :user_id_uuid, :user_id
    change_column_null :user_permissions, :user_id, false

    # Add foreign key constraint
    add_foreign_key :user_permissions, :users_new, column: :user_id, type: :uuid

    # Drop old table and rename new table
    drop_table :users
    rename_table :users_new, :users
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
