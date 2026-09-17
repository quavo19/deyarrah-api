class SeedDeliveryDefaults < ActiveRecord::Migration[7.1]
  def up
    now = Time.current

    zones = [
      { name: "Upper East - All Towns", code: "upper_east_all_towns", pricing_zone: "near", region: "Upper East", city: nil, station_name: nil },
      { name: "Tamale Market/Bus Station", code: "tamale_station", pricing_zone: "far", region: "Northern", city: "Tamale", station_name: "Market/Bus Station" },
      { name: "Wa Market/Bus Station", code: "wa_station", pricing_zone: "far", region: "Upper West", city: "Wa", station_name: "Market/Bus Station" },
      { name: "Tumu Market/Bus Station", code: "tumu_station", pricing_zone: "far", region: "Upper West", city: "Tumu", station_name: "Market/Bus Station" },
      { name: "Kumasi Market/Bus Station", code: "kumasi_station", pricing_zone: "far", region: "Ashanti", city: "Kumasi", station_name: "Market/Bus Station" },
      { name: "Accra Market/Bus Station", code: "accra_station", pricing_zone: "far", region: "Greater Accra", city: "Accra", station_name: "Market/Bus Station" }
    ]

    zones.each do |zone|
      city_sql = zone[:city].nil? ? "NULL" : quote(zone[:city])
      station_name_sql = zone[:station_name].nil? ? "NULL" : quote(zone[:station_name])
      execute <<~SQL.squish
        INSERT INTO delivery_zones (id, name, code, pricing_zone, region, city, station_name, active, created_at, updated_at)
        VALUES (gen_random_uuid(), #{quote(zone[:name])}, #{quote(zone[:code])}, #{quote(zone[:pricing_zone])}, #{quote(zone[:region])}, #{city_sql}, #{station_name_sql}, TRUE, #{quote(now)}, #{quote(now)})
        ON CONFLICT (code) DO NOTHING
      SQL
    end

    [
      [ "near", 0, 5, 20 ],
      [ "near", 5, 15, 50 ],
      [ "near", 15, 30, 100 ],
      [ "near", 30, nil, 150 ],
      [ "far", 0, 5, 35 ],
      [ "far", 5, 15, 80 ],
      [ "far", 15, 30, 150 ],
      [ "far", 30, nil, 220 ]
    ].each do |pricing_zone, min_weight, max_weight, fee|
      max_weight_sql = max_weight.nil? ? "NULL" : quote(max_weight)
      execute <<~SQL.squish
        INSERT INTO delivery_weight_tiers (id, pricing_zone, min_weight_kg, max_weight_kg, fee, created_at, updated_at)
        SELECT gen_random_uuid(), #{quote(pricing_zone)}, #{quote(min_weight)}, #{max_weight_sql}, #{quote(fee)}, #{quote(now)}, #{quote(now)}
        WHERE NOT EXISTS (
          SELECT 1 FROM delivery_weight_tiers
          WHERE pricing_zone = #{quote(pricing_zone)}
            AND min_weight_kg = #{quote(min_weight)}
            AND COALESCE(max_weight_kg, -1) = COALESCE(#{max_weight_sql}, -1)
        )
      SQL
    end

    [
      [ "near", "phone", 100 ],
      [ "far", "phone", 150 ],
      [ "near", "laptop", 120 ],
      [ "far", "laptop", 200 ],
      [ "near", "electronics", 100 ],
      [ "far", "electronics", 150 ]
    ].each do |pricing_zone, category, fee|
      execute <<~SQL.squish
        INSERT INTO delivery_high_value_rates (id, pricing_zone, shipping_category, fee, created_at, updated_at)
        VALUES (gen_random_uuid(), #{quote(pricing_zone)}, #{quote(category)}, #{quote(fee)}, #{quote(now)}, #{quote(now)})
        ON CONFLICT (pricing_zone, shipping_category) DO NOTHING
      SQL
    end

    execute <<~SQL.squish
      INSERT INTO delivery_settings (id, key, value, created_at, updated_at)
      VALUES (gen_random_uuid(), 'high_value_additional_unit_multiplier', '{"multiplier": 0.75}'::jsonb, #{quote(now)}, #{quote(now)})
      ON CONFLICT (key) DO NOTHING
    SQL
  end

  def down
    execute "DELETE FROM delivery_settings WHERE key = 'high_value_additional_unit_multiplier'"
    execute "DELETE FROM delivery_high_value_rates WHERE shipping_category IN ('phone', 'laptop', 'electronics')"
    execute "DELETE FROM delivery_weight_tiers WHERE pricing_zone IN ('near', 'far')"
    execute "DELETE FROM delivery_zones WHERE code IN ('upper_east_all_towns', 'tamale_station', 'wa_station', 'tumu_station', 'kumasi_station', 'accra_station')"
  end
end
