class MakeBookingProductIdNullable < ActiveRecord::Migration[8.0]
  def up
    # Remove foreign key constraint
    remove_foreign_key :bookings, :products
    
    # Make column nullable
    change_column_null :bookings, :product_id, true
    
    # Re-add foreign key constraint with null allowed
    add_foreign_key :bookings, :products, on_delete: :nullify
  end

  def down
    remove_foreign_key :bookings, :products
    change_column_null :bookings, :product_id, false
    add_foreign_key :bookings, :products
  end
end
