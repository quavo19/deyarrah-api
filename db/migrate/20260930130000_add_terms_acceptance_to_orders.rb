class AddTermsAcceptanceToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :terms_accepted_at, :datetime
    add_column :orders, :terms_version, :string
    add_index :orders, :terms_accepted_at
  end
end
