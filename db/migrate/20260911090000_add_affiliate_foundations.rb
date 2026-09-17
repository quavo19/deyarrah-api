class AddAffiliateFoundations < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :affiliate_commission_amount, :decimal, precision: 10, scale: 2, default: 0.0, null: false unless column_exists?(:products, :affiliate_commission_amount)
    add_check_constraint :products, "affiliate_commission_amount >= 0", name: "products_affiliate_commission_amount_non_negative" unless check_constraint_exists?(:products, name: "products_affiliate_commission_amount_non_negative")

    create_table :affiliate_profiles, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.references :reviewed_by, foreign_key: { to_table: :users }, type: :uuid
      t.string :status, null: false, default: "pending"
      t.string :affiliate_code, null: false
      t.string :full_name
      t.string :email
      t.string :phone
      t.string :country
      t.string :city
      t.jsonb :social_links, null: false, default: []
      t.jsonb :promotion_channels, null: false, default: []
      t.integer :audience_size
      t.string :content_niche
      t.text :reason
      t.jsonb :payout_details, null: false, default: {}
      t.boolean :terms_accepted, null: false, default: false
      t.datetime :reviewed_at
      t.text :rejection_reason
      t.datetime :suspended_at
      t.timestamps
    end

    add_index :affiliate_profiles, :affiliate_code, unique: true
    add_index :affiliate_profiles, :status
    add_check_constraint :affiliate_profiles, "audience_size IS NULL OR audience_size >= 0", name: "affiliate_profiles_audience_size_non_negative"

    create_table :affiliate_clicks, id: :uuid do |t|
      t.references :affiliate_user, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.references :buyer_user, foreign_key: { to_table: :users }, type: :uuid
      t.string :visitor_id
      t.string :ip_hash
      t.text :user_agent
      t.text :referrer
      t.datetime :clicked_at, null: false
      t.timestamps
    end

    add_index :affiliate_clicks, [ :product_id, :visitor_id ]
    add_index :affiliate_clicks, [ :product_id, :buyer_user_id ]
    add_index :affiliate_clicks, :clicked_at

    create_table :affiliate_attributions, id: :uuid do |t|
      t.references :affiliate_user, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.references :buyer_user, foreign_key: { to_table: :users }, type: :uuid
      t.references :affiliate_click, foreign_key: true, type: :uuid
      t.string :visitor_id
      t.datetime :attributed_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :converted_at
      t.timestamps
    end

    add_index :affiliate_attributions, [ :product_id, :visitor_id ], unique: true, where: "buyer_user_id IS NULL AND visitor_id IS NOT NULL", name: "idx_affiliate_attr_unique_product_visitor"
    add_index :affiliate_attributions, [ :product_id, :buyer_user_id ], unique: true, where: "buyer_user_id IS NOT NULL", name: "idx_affiliate_attr_unique_product_buyer"
    add_index :affiliate_attributions, :expires_at
    add_index :affiliate_attributions, :converted_at

    create_table :affiliate_earnings, id: :uuid do |t|
      t.references :affiliate_user, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.references :buyer_user, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.references :order_item, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.references :affiliate_attribution, foreign_key: true, type: :uuid
      t.string :status, null: false, default: "pending"
      t.decimal :sale_amount, precision: 12, scale: 2, null: false, default: 0.0
      t.decimal :commission_amount, precision: 12, scale: 2, null: false, default: 0.0
      t.string :currency, null: false, default: "GHS"
      t.datetime :earned_at, null: false
      t.datetime :available_at
      t.datetime :withdrawn_at
      t.timestamps
    end

    add_index :affiliate_earnings, [ :affiliate_user_id, :status ]
    add_index :affiliate_earnings, :earned_at
    add_check_constraint :affiliate_earnings, "sale_amount >= 0", name: "affiliate_earnings_sale_amount_non_negative"
    add_check_constraint :affiliate_earnings, "commission_amount >= 0", name: "affiliate_earnings_commission_amount_non_negative"

    create_table :affiliate_withdrawals, id: :uuid do |t|
      t.references :affiliate_user, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.references :reviewed_by, foreign_key: { to_table: :users }, type: :uuid
      t.string :status, null: false, default: "pending"
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :currency, null: false, default: "GHS"
      t.jsonb :payout_details, null: false, default: {}
      t.datetime :requested_at, null: false
      t.datetime :reviewed_at
      t.datetime :paid_at
      t.text :admin_note
      t.timestamps
    end

    add_index :affiliate_withdrawals, [ :affiliate_user_id, :status ]
    add_index :affiliate_withdrawals, :requested_at
    add_check_constraint :affiliate_withdrawals, "amount > 0", name: "affiliate_withdrawals_amount_positive"
  end
end
