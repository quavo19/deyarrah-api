class AllowManualCustomerAddresses < ActiveRecord::Migration[8.0]
  def change
    change_column_null :customer_addresses, :latitude, true
    change_column_null :customer_addresses, :longitude, true
  end
end
