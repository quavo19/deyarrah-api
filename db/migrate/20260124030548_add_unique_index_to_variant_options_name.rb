class AddUniqueIndexToVariantOptionsName < ActiveRecord::Migration[8.0]
  def up
    # Remove any duplicate records first (case-insensitive)
    execute <<-SQL
      DELETE FROM variant_options a
      USING variant_options b
      WHERE a.id > b.id
        AND LOWER(a.name) = LOWER(b.name)
        AND a.variant_type_id = b.variant_type_id;
    SQL

    # Add case-insensitive unique index
    execute <<-SQL
      CREATE UNIQUE INDEX index_variant_options_on_variant_type_id_and_lower_name
      ON variant_options (variant_type_id, LOWER(name));
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS index_variant_options_on_variant_type_id_and_lower_name;"
  end
end
