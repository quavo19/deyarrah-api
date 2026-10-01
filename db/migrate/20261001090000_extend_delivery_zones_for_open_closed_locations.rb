class ExtendDeliveryZonesForOpenClosedLocations < ActiveRecord::Migration[8.0]
  def change
    add_column :delivery_zones, :town, :string
    add_column :delivery_zones, :market_name, :string
    add_column :delivery_zones, :region_open, :boolean, null: false, default: false
    add_column :delivery_zones, :city_open, :boolean, null: false, default: false
    add_column :delivery_zones, :town_open, :boolean, null: false, default: false

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE delivery_zones
          SET region_open = TRUE
          WHERE (city IS NULL OR city = '')
        SQL
      end
    end

    add_index :delivery_zones, :town
    add_index :delivery_zones, :market_name
    add_index :delivery_zones, [ :region, :city, :town, :market_name ], name: "index_delivery_zones_on_location_hierarchy"

    add_column :customer_addresses, :town, :string
    add_column :customer_addresses, :market_name, :string
    add_column :customer_addresses, :delivery_zone_id, :uuid

    add_index :customer_addresses, :town
    add_index :customer_addresses, :market_name
    add_index :customer_addresses, :delivery_zone_id
    add_foreign_key :customer_addresses, :delivery_zones
  end
end
