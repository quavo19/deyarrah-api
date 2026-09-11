class AddStatusToSupportRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :support_requests, :status, :string, default: "pending", null: false unless column_exists?(:support_requests, :status)
    add_index :support_requests, :status unless index_exists?(:support_requests, :status)
  end
end
