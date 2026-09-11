# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_08_15_020000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "badges", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "bonus_points", default: 0, null: false
    t.index ["name"], name: "index_badges_on_name", unique: true
    t.check_constraint "bonus_points >= 0", name: "badges_bonus_points_non_negative"
  end

  create_table "bonuses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.decimal "balance", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_bonuses_on_user_id", unique: true
  end

  create_table "cart_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "variant_stock_id"
    t.integer "quantity", default: 1, null: false
    t.index ["product_id"], name: "index_cart_items_on_product_id"
    t.index ["user_id", "product_id", "variant_stock_id"], name: "index_cart_items_on_user_product_variant", unique: true
    t.index ["user_id"], name: "index_cart_items_on_user_id"
    t.index ["variant_stock_id"], name: "index_cart_items_on_variant_stock_id"
    t.check_constraint "quantity > 0", name: "cart_items_quantity_positive"
  end

  create_table "categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "contact_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "purpose", null: false
    t.text "message", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_contact_messages_on_created_at"
    t.index ["email"], name: "index_contact_messages_on_email"
    t.index ["name"], name: "index_contact_messages_on_name"
    t.index ["phone"], name: "index_contact_messages_on_phone"
  end

  create_table "customer_addresses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", null: false
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "country"
    t.string "region"
    t.string "city"
    t.string "county"
    t.jsonb "address", default: {}
    t.boolean "is_default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["address"], name: "index_customer_addresses_on_address", using: :gin
    t.index ["is_default"], name: "index_customer_addresses_on_is_default"
    t.index ["latitude", "longitude"], name: "index_customer_addresses_on_latitude_and_longitude"
    t.index ["name"], name: "index_customer_addresses_on_name"
    t.index ["user_id"], name: "index_customer_addresses_on_user_id"
  end

  create_table "downtimes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "variant_stock_id", null: false
    t.datetime "start_at", null: false
    t.datetime "end_at", null: false
    t.datetime "ended_at"
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["end_at"], name: "index_downtimes_on_end_at"
    t.index ["start_at"], name: "index_downtimes_on_start_at"
    t.index ["variant_stock_id"], name: "index_downtimes_on_variant_stock_id"
  end

  create_table "fulfillment_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "fulfillment_id", null: false
    t.uuid "order_item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fulfillment_id", "order_item_id"], name: "index_fulfillment_items_on_fulfillment_and_booking_item", unique: true
    t.index ["fulfillment_id"], name: "index_fulfillment_items_on_fulfillment_id"
    t.index ["order_item_id"], name: "index_fulfillment_items_on_order_item_id"
  end

  create_table "fulfillments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "order_id", null: false
    t.uuid "warehouse_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "delivery_date"
    t.decimal "delivery_fee", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "warehouse_latitude", precision: 10, scale: 7
    t.decimal "warehouse_longitude", precision: 10, scale: 7
    t.index ["delivery_date"], name: "index_fulfillments_on_delivery_date"
    t.index ["order_id"], name: "index_fulfillments_on_order_id"
    t.index ["status"], name: "index_fulfillments_on_status"
    t.index ["warehouse_id"], name: "index_fulfillments_on_warehouse_id"
  end

  create_table "images", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "owner_type", null: false
    t.uuid "owner_id", null: false
    t.string "url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_images_on_owner"
    t.index ["owner_type", "owner_id"], name: "index_images_on_owner_type_and_owner_id"
  end

  create_table "jwt_denylist", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.index ["jti"], name: "index_jwt_denylist_on_jti"
  end

  create_table "order_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "order_id", null: false
    t.uuid "variant_stock_id"
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "variant_stock_price", precision: 10, scale: 2
    t.integer "variant_stock_quantity"
    t.text "variant_stock_option_names"
    t.string "variant_stock_warehouse_name"
    t.jsonb "variant_stock_warehouse_address", default: {}
    t.decimal "variant_stock_warehouse_latitude", precision: 10, scale: 7
    t.decimal "variant_stock_warehouse_longitude", precision: 10, scale: 7
    t.string "variant_stock_warehouse_country"
    t.string "variant_stock_warehouse_region"
    t.string "variant_stock_warehouse_city"
    t.string "variant_stock_warehouse_county"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["variant_stock_id"], name: "index_order_items_on_variant_stock_id"
  end

  create_table "orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "customer_address_id"
    t.decimal "delivery_distance", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "delivery_fee", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "item_subtotal", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "delivery_address_name"
    t.decimal "delivery_latitude", precision: 10, scale: 7
    t.decimal "delivery_longitude", precision: 10, scale: 7
    t.text "phones", default: [], array: true
    t.uuid "assigned_to_id"
    t.string "payment_status", default: "pending", null: false
    t.string "order_id", limit: 7, null: false
    t.datetime "bonus_points_awarded_at"
    t.datetime "received_bonus_awarded_at"
    t.index ["assigned_to_id"], name: "index_orders_on_assigned_to_id"
    t.index ["customer_address_id"], name: "index_orders_on_customer_address_id"
    t.index ["order_id"], name: "index_orders_on_order_id", unique: true
    t.index ["payment_status"], name: "index_orders_on_payment_status"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_permissions_on_name", unique: true
  end

  create_table "product_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "product_id", null: false
    t.uuid "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_product_categories_on_category_id"
    t.index ["product_id", "category_id"], name: "index_product_categories_on_product_id_and_category_id", unique: true
    t.index ["product_id"], name: "index_product_categories_on_product_id"
  end

  create_table "product_meta", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "product_id", null: false
    t.string "name", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "name"], name: "index_product_meta_on_product_id_and_name"
    t.index ["product_id"], name: "index_product_meta_on_product_id"
  end

  create_table "product_sub_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "product_id", null: false
    t.uuid "sub_category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "sub_category_id"], name: "index_product_sub_categories_on_product_id_and_sub_category_id", unique: true
    t.index ["product_id"], name: "index_product_sub_categories_on_product_id"
    t.index ["sub_category_id"], name: "index_product_sub_categories_on_sub_category_id"
  end

  create_table "products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "bookable_type", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "category_id"
    t.string "status", default: "available"
    t.decimal "delivery_rate_per_km", precision: 10, scale: 2, default: "10.0", null: false
    t.integer "bonus_points", default: 0, null: false
    t.index ["active"], name: "index_products_on_active"
    t.index ["bookable_type"], name: "index_products_on_bookable_type"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["status"], name: "index_products_on_status"
    t.check_constraint "bonus_points >= 0", name: "products_bonus_points_non_negative"
  end

  create_table "reviews", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "product_id", null: false
    t.uuid "user_id", null: false
    t.integer "points", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "user_id"], name: "index_reviews_on_product_id_and_user_id"
    t.index ["product_id"], name: "index_reviews_on_product_id"
    t.index ["user_id"], name: "index_reviews_on_user_id"
    t.check_constraint "points >= 0 AND points <= 5", name: "reviews_points_between_0_and_5"
  end

  create_table "roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "sub_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "category_id", null: false
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id", "name"], name: "index_sub_categories_on_category_id_and_name", unique: true
    t.index ["category_id"], name: "index_sub_categories_on_category_id"
  end

  create_table "support_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.string "topic", null: false
    t.text "message", null: false
    t.string "guest_full_name"
    t.string "guest_email"
    t.string "guest_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "pending", null: false
    t.index ["created_at"], name: "index_support_requests_on_created_at"
    t.index ["guest_email"], name: "index_support_requests_on_guest_email"
    t.index ["status"], name: "index_support_requests_on_status"
    t.index ["topic"], name: "index_support_requests_on_topic"
    t.index ["user_id"], name: "index_support_requests_on_user_id"
  end

  create_table "transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "order_id", null: false
    t.integer "amount_kobo", null: false
    t.string "currency", default: "GHS", null: false
    t.string "status", default: "initialized", null: false
    t.string "provider", default: "paystack", null: false
    t.string "provider_reference", null: false
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_transactions_on_order_id"
    t.index ["provider_reference"], name: "index_transactions_on_provider_reference", unique: true
    t.index ["status"], name: "index_transactions_on_status"
  end

  create_table "user_badges", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "badge_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["badge_id"], name: "index_user_badges_on_badge_id"
    t.index ["created_at"], name: "index_user_badges_on_created_at"
    t.index ["user_id", "badge_id"], name: "index_user_badges_on_user_id_and_badge_id", unique: true
    t.index ["user_id"], name: "index_user_badges_on_user_id"
  end

  create_table "user_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "permission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["permission_id"], name: "index_user_permissions_on_permission_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
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
    t.uuid "role_id"
    t.boolean "blocked", default: false, null: false
    t.boolean "otp_enabled", default: false, null: false
    t.string "otp_secret"
    t.datetime "otp_verified_at"
    t.string "provider"
    t.string "uid"
    t.text "phone_numbers", default: [], null: false, array: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "((provider IS NOT NULL) AND (uid IS NOT NULL))"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
  end

  create_table "variant_options", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "variant_type_id", null: false
    t.string "name", null: false
    t.text "description"
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "variant_type_id, lower((name)::text)", name: "index_variant_options_on_variant_type_id_and_lower_name", unique: true
    t.index ["variant_type_id"], name: "index_variant_options_on_variant_type_id"
  end

  create_table "variant_stocks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "option_ids", default: [], null: false, array: true
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "warehouse_id", null: false
    t.uuid "product_id"
    t.index ["option_ids"], name: "index_variant_stocks_on_option_ids", using: :gin
    t.index ["product_id"], name: "index_variant_stocks_on_product_id"
    t.index ["warehouse_id"], name: "index_variant_stocks_on_warehouse_id"
  end

  create_table "variant_types", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "product_id", null: false
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pricing_role"
    t.index ["pricing_role"], name: "index_variant_types_on_pricing_role"
    t.index ["product_id"], name: "index_variant_types_on_product_id"
  end

  create_table "warehouses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.decimal "latitude", precision: 10, scale: 7, null: false
    t.decimal "longitude", precision: 10, scale: 7, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "country"
    t.string "region"
    t.string "city"
    t.string "county"
    t.jsonb "address", default: {}
    t.decimal "delivery_rate_per_km", precision: 10, scale: 2, default: "50.0", null: false
    t.index ["address"], name: "index_warehouses_on_address", using: :gin
    t.index ["city"], name: "index_warehouses_on_city"
    t.index ["country"], name: "index_warehouses_on_country"
    t.index ["county"], name: "index_warehouses_on_county"
    t.index ["latitude", "longitude"], name: "index_warehouses_on_latitude_and_longitude"
    t.index ["name"], name: "index_warehouses_on_name"
    t.index ["region"], name: "index_warehouses_on_region"
  end

  create_table "wishlist_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_wishlist_items_on_product_id"
    t.index ["user_id", "product_id"], name: "index_wishlist_items_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_wishlist_items_on_user_id"
  end

  add_foreign_key "bonuses", "users"
  add_foreign_key "cart_items", "products"
  add_foreign_key "cart_items", "users"
  add_foreign_key "cart_items", "variant_stocks"
  add_foreign_key "customer_addresses", "users"
  add_foreign_key "downtimes", "variant_stocks"
  add_foreign_key "fulfillment_items", "fulfillments"
  add_foreign_key "fulfillment_items", "order_items"
  add_foreign_key "fulfillments", "orders"
  add_foreign_key "fulfillments", "warehouses"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "variant_stocks", on_delete: :nullify
  add_foreign_key "orders", "customer_addresses"
  add_foreign_key "orders", "users"
  add_foreign_key "orders", "users", column: "assigned_to_id"
  add_foreign_key "product_categories", "categories"
  add_foreign_key "product_categories", "products"
  add_foreign_key "product_meta", "products"
  add_foreign_key "product_sub_categories", "products"
  add_foreign_key "product_sub_categories", "sub_categories"
  add_foreign_key "products", "categories"
  add_foreign_key "reviews", "products"
  add_foreign_key "reviews", "users"
  add_foreign_key "sub_categories", "categories"
  add_foreign_key "support_requests", "users"
  add_foreign_key "transactions", "orders"
  add_foreign_key "user_badges", "badges"
  add_foreign_key "user_badges", "users"
  add_foreign_key "user_permissions", "permissions"
  add_foreign_key "user_permissions", "users"
  add_foreign_key "users", "roles"
  add_foreign_key "variant_options", "variant_types"
  add_foreign_key "variant_stocks", "products"
  add_foreign_key "variant_stocks", "warehouses"
  add_foreign_key "variant_types", "products"
  add_foreign_key "wishlist_items", "products"
  add_foreign_key "wishlist_items", "users"
end
