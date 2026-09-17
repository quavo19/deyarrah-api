class SeedAffiliateRole < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      INSERT INTO roles (id, name, description, created_at, updated_at)
      VALUES (
        gen_random_uuid(),
        'AFFILIATE',
        'Affiliate marketer with customer shopping access and affiliate selling privileges',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      )
      ON CONFLICT (name) DO UPDATE
      SET description = EXCLUDED.description,
          updated_at = CURRENT_TIMESTAMP
    SQL
  end

  def down
    execute <<~SQL.squish
      DELETE FROM roles
      WHERE name = 'AFFILIATE'
      AND NOT EXISTS (
        SELECT 1 FROM users WHERE users.role_id = roles.id
      )
    SQL
  end
end
