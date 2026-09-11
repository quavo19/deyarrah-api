class AddBonusesAndBadges < ActiveRecord::Migration[8.0]
  def up
    create_table :bonuses, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true, index: false
      t.decimal :balance, precision: 12, scale: 2, default: 0.0, null: false
      t.timestamps
    end

    add_index :bonuses, :user_id, unique: true

    create_table :badges, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    add_index :badges, :name, unique: true

    create_table :user_badges, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :badge, null: false, type: :uuid, foreign_key: true
      t.timestamps
    end

    add_index :user_badges, [ :user_id, :badge_id ], unique: true
    add_index :user_badges, :created_at

    execute <<~SQL.squish
      INSERT INTO bonuses (id, user_id, balance, created_at, updated_at)
      SELECT gen_random_uuid(), users.id, 0.0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM users
      LEFT JOIN bonuses ON bonuses.user_id = users.id
      WHERE bonuses.id IS NULL
    SQL
  end

  def down
    drop_table :user_badges
    drop_table :badges
    drop_table :bonuses
  end
end
