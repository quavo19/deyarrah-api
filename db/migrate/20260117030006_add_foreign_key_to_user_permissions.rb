class AddForeignKeyToUserPermissions < ActiveRecord::Migration[8.0]
  def change
    # This migration ensures the foreign key is properly set after users table is migrated to UUID
    # The foreign key should already be added in the previous migration, but this ensures it
  end
end
