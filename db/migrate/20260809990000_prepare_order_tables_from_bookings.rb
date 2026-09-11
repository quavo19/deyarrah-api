class PrepareOrderTablesFromBookings < ActiveRecord::Migration[8.0]
  def up
    rename_table :bookings, :orders if table_exists?(:bookings) && !table_exists?(:orders)
    rename_table :booking_items, :order_items if table_exists?(:booking_items) && !table_exists?(:order_items)

    rename_column_if_present :order_items, :booking_id, :order_id
    rename_column_if_present :fulfillments, :booking_id, :order_id
    rename_column_if_present :fulfillment_items, :booking_item_id, :order_item_id
    rename_column_if_present :transactions, :booking_id, :order_id
  end

  def down
    rename_column_if_present :transactions, :order_id, :booking_id
    rename_column_if_present :fulfillment_items, :order_item_id, :booking_item_id
    rename_column_if_present :fulfillments, :order_id, :booking_id
    rename_column_if_present :order_items, :order_id, :booking_id

    rename_table :order_items, :booking_items if table_exists?(:order_items) && !table_exists?(:booking_items)
    rename_table :orders, :bookings if table_exists?(:orders) && !table_exists?(:bookings)
  end

  private

  def rename_column_if_present(table_name, old_name, new_name)
    return unless table_exists?(table_name)
    return unless column_exists?(table_name, old_name)
    return if column_exists?(table_name, new_name)

    rename_column table_name, old_name, new_name
  end
end
