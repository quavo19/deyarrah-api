class RemoveOrderFieldsForOrders < ActiveRecord::Migration[8.0]
  def change
    remove_index :orders, :start_at, if_exists: true
    remove_index :orders, :end_at, if_exists: true
    remove_reference :orders, :product, foreign_key: true, type: :uuid, index: true

    remove_column :orders, :start_at, :datetime
    remove_column :orders, :end_at, :datetime
    remove_column :orders, :product_name, :string
    remove_column :orders, :product_description, :text
    remove_column :orders, :product_bookable_type, :string
    remove_column :orders, :product_delivery_rate_per_km, :decimal, precision: 10, scale: 2
  end
end
