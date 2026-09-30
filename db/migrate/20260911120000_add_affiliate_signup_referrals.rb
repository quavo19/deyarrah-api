class AddAffiliateSignupReferrals < ActiveRecord::Migration[8.0]
  def change
    create_table :affiliate_settings, id: :uuid do |t|
      t.decimal :signup_referral_percentage, precision: 5, scale: 2, default: 0, null: false
      t.decimal :signup_referral_cap_amount, precision: 12, scale: 2, default: 0, null: false
      t.boolean :signup_referral_enabled, default: true, null: false

      t.timestamps
    end

    add_check_constraint :affiliate_settings, "signup_referral_percentage >= 0", name: "affiliate_settings_signup_percentage_non_negative"
    add_check_constraint :affiliate_settings, "signup_referral_cap_amount >= 0", name: "affiliate_settings_signup_cap_non_negative"

    create_table :affiliate_signup_referrals, id: :uuid do |t|
      t.references :affiliate_user, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :referred_user, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.string :visitor_id
      t.datetime :referred_at, null: false
      t.datetime :converted_at
      t.integer :rewarded_orders_count, default: 0, null: false

      t.timestamps
    end

    add_index :affiliate_signup_referrals, :visitor_id
    add_index :affiliate_signup_referrals, :converted_at
    remove_index :affiliate_signup_referrals, :referred_user_id
    add_index :affiliate_signup_referrals, :referred_user_id, unique: true
    add_check_constraint :affiliate_signup_referrals, "rewarded_orders_count >= 0 AND rewarded_orders_count <= 3", name: "affiliate_signup_referrals_rewarded_orders_count_range"

    change_column_null :affiliate_earnings, :order_item_id, true
    change_column_null :affiliate_earnings, :product_id, true
    add_reference :affiliate_earnings, :affiliate_signup_referral, type: :uuid, foreign_key: true
    add_column :affiliate_earnings, :earning_type, :string, default: "product_commission", null: false
    add_index :affiliate_earnings, :earning_type
    add_index :affiliate_earnings, [ :affiliate_signup_referral_id, :order_id ], unique: true, where: "affiliate_signup_referral_id IS NOT NULL", name: "idx_affiliate_earnings_unique_signup_order"
  end
end
