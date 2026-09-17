class AddDeliveryAndProductSearchFields < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :shipping_type, :string, null: false, default: "bulk"
    add_column :products, :weight_kg, :decimal, precision: 10, scale: 2
    add_column :products, :weight_class, :string, null: false, default: "medium"
    add_column :products, :shipping_category, :string
    add_column :products, :search_keywords, :text, array: true, null: false, default: []

    add_index :products, :shipping_type
    add_index :products, :shipping_category
    add_index :products, :search_keywords, using: :gin

    add_check_constraint :products, "shipping_type IN ('bulk', 'high_value')", name: "products_shipping_type_valid"
    add_check_constraint :products, "weight_class IS NULL OR weight_class IN ('light', 'medium', 'heavy')", name: "products_weight_class_valid"
    add_check_constraint :products, "weight_kg IS NULL OR weight_kg >= 0", name: "products_weight_kg_non_negative"

    create_table :delivery_zones, id: :uuid do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :pricing_zone, null: false
      t.string :region
      t.string :city
      t.string :station_name
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :delivery_zones, :code, unique: true
    add_index :delivery_zones, :pricing_zone
    add_index :delivery_zones, :region
    add_index :delivery_zones, :city
    add_check_constraint :delivery_zones, "pricing_zone IN ('near', 'far')", name: "delivery_zones_pricing_zone_valid"

    create_table :delivery_weight_tiers, id: :uuid do |t|
      t.string :pricing_zone, null: false
      t.decimal :min_weight_kg, precision: 10, scale: 2, null: false, default: 0
      t.decimal :max_weight_kg, precision: 10, scale: 2
      t.decimal :fee, precision: 10, scale: 2, null: false
      t.timestamps
    end

    add_index :delivery_weight_tiers, [ :pricing_zone, :min_weight_kg, :max_weight_kg ], name: "index_delivery_weight_tiers_on_zone_and_weight"
    add_check_constraint :delivery_weight_tiers, "pricing_zone IN ('near', 'far')", name: "delivery_weight_tiers_pricing_zone_valid"
    add_check_constraint :delivery_weight_tiers, "min_weight_kg >= 0", name: "delivery_weight_tiers_min_weight_non_negative"
    add_check_constraint :delivery_weight_tiers, "max_weight_kg IS NULL OR max_weight_kg > min_weight_kg", name: "delivery_weight_tiers_max_above_min"
    add_check_constraint :delivery_weight_tiers, "fee >= 0", name: "delivery_weight_tiers_fee_non_negative"

    create_table :delivery_high_value_rates, id: :uuid do |t|
      t.string :pricing_zone, null: false
      t.string :shipping_category, null: false
      t.decimal :fee, precision: 10, scale: 2, null: false
      t.timestamps
    end

    add_index :delivery_high_value_rates, [ :pricing_zone, :shipping_category ], unique: true, name: "index_delivery_high_value_rates_on_zone_and_category"
    add_check_constraint :delivery_high_value_rates, "pricing_zone IN ('near', 'far')", name: "delivery_high_value_rates_pricing_zone_valid"
    add_check_constraint :delivery_high_value_rates, "fee >= 0", name: "delivery_high_value_rates_fee_non_negative"

    create_table :delivery_settings, id: :uuid do |t|
      t.string :key, null: false
      t.jsonb :value, null: false, default: {}
      t.timestamps
    end

    add_index :delivery_settings, :key, unique: true
  end
end
