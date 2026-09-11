class AddAddressIdToOrders < ActiveRecord::Migration[8.0]
  def change
    # add_reference automatically creates an index, so we don't need add_index
    add_reference :orders, :customer_address, null: true, foreign_key: true, type: :uuid, index: true
  end
end
