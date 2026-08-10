class AddRoleAndOtpToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :role, null: true, foreign_key: true, type: :uuid
    add_column :users, :blocked, :boolean, default: false, null: false
    add_column :users, :otp_enabled, :boolean, default: false, null: false
    add_column :users, :otp_secret, :string
    add_column :users, :otp_verified_at, :datetime
  end
end
