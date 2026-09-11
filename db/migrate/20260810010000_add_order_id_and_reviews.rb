class AddOrderIdAndReviews < ActiveRecord::Migration[8.0]
  ORDER_ID_LENGTH = 7
  ORDER_ID_ALPHABET = [ *"A".."Z", *"0".."9" ].freeze

  def up
    raise "orders table is missing. Run PrepareOrderTablesFromBookings first." unless table_exists?(:orders)

    remove_obsolete_order_columns

    add_column :orders, :order_id, :string, limit: 7 unless column_exists?(:orders, :order_id)
    add_index :orders, :order_id, unique: true unless index_exists?(:orders, :order_id, unique: true)

    say_with_time "Backfilling order IDs" do
      execute("SELECT id FROM orders WHERE order_id IS NULL").each do |row|
        order_id = unique_order_id
        execute sanitize_sql([ "UPDATE orders SET order_id = ? WHERE id = ?", order_id, row["id"] ])
      end
    end

    change_column_null :orders, :order_id, false

    unless table_exists?(:reviews)
      create_table :reviews, id: :uuid do |t|
        t.references :product, null: false, foreign_key: true, type: :uuid
        t.references :user, null: false, foreign_key: true, type: :uuid
        t.integer :points, null: false
        t.text :comment

        t.timestamps
      end
    end

    add_index :reviews, [ :product_id, :user_id ] unless index_exists?(:reviews, [ :product_id, :user_id ])
    unless check_constraint_exists?(:reviews, name: "reviews_points_between_0_and_5")
      add_check_constraint :reviews, "points >= 0 AND points <= 5", name: "reviews_points_between_0_and_5"
    end
  end

  def down
    drop_table :reviews if table_exists?(:reviews)
    remove_index :orders, :order_id if table_exists?(:orders) && index_exists?(:orders, :order_id)
    remove_column :orders, :order_id if table_exists?(:orders) && column_exists?(:orders, :order_id)
  end

  private

  def unique_order_id
    loop do
      candidate = Array.new(ORDER_ID_LENGTH) { ORDER_ID_ALPHABET.sample }.join
      exists = select_value sanitize_sql([ "SELECT 1 FROM orders WHERE order_id = ? LIMIT 1", candidate ])
      return candidate unless exists
    end
  end

  def sanitize_sql(args)
    ActiveRecord::Base.sanitize_sql_array(args)
  end

  def remove_obsolete_order_columns
    remove_index :orders, :start_at if index_exists?(:orders, :start_at)
    remove_index :orders, :end_at if index_exists?(:orders, :end_at)

    if column_exists?(:orders, :product_id)
      remove_foreign_key :orders, :products if foreign_key_exists?(:orders, :products)
      remove_index :orders, :product_id if index_exists?(:orders, :product_id)
      remove_column :orders, :product_id
    end

    [
      [ :start_at, :datetime ],
      [ :end_at, :datetime ],
      [ :product_name, :string ],
      [ :product_description, :text ],
      [ :product_bookable_type, :string ],
      [ :product_delivery_rate_per_km, :decimal ]
    ].each do |column_name, column_type|
      remove_column :orders, column_name, column_type if column_exists?(:orders, column_name)
    end
  end
end
