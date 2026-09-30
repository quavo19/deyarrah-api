# Create Roles
roles_data = [
  { name: 'CUSTOMER', description: 'Default user role with basic access' },
  { name: 'AFFILIATE', description: 'Affiliate marketer with customer shopping access and affiliate selling privileges' },
  { name: 'STAFF', description: 'Staff member with limited administrative access' },
  { name: 'ADMIN', description: 'Administrator with full system access' },
  { name: 'SUPER_ADMIN', description: 'Super administrator with complete system control' }
]

roles_data.each do |role_data|
  Role.find_or_create_by(name: role_data[:name]) do |role|
    role.description = role_data[:description]
  end
end

# Create Permissions
permissions_data = [
  'CAN_PAY_ON_DELIVERY'
]

permissions_data.each do |permission_name|
  Permission.find_or_create_by(name: permission_name)
end

puts "Seeded #{Role.count} roles and #{Permission.count} permissions"

affiliate_seed_profiles = [
  {
    user: { email: "affiliate.pending.one@example.com", first_name: "Ama", last_name: "Mensah" },
    profile: {
      status: "pending",
      full_name: "Ama Mensah",
      phone: "+233555000101",
      country: "Ghana",
      city: "Bolgatanga",
      social_links: [ "https://instagram.com/amamensah" ],
      promotion_channels: [ "Instagram", "TikTok" ],
      audience_size: 4800,
      content_niche: "Home goods and lifestyle",
      reason: "I create short product videos for shoppers in Upper East and want to promote products weekly.",
      payout_details: { provider: "mobile_money", account_name: "Ama Mensah", account_number: "+233555000101" },
      terms_accepted: true
    }
  },
  {
    user: { email: "affiliate.pending.two@example.com", first_name: "Kojo", last_name: "Boateng" },
    profile: {
      status: "pending",
      full_name: "Kojo Boateng",
      phone: "+233555000102",
      country: "Ghana",
      city: "Tamale",
      social_links: [ "https://facebook.com/kojobdeals", "https://tiktok.com/@kojobdeals" ],
      promotion_channels: [ "Facebook", "WhatsApp", "TikTok" ],
      audience_size: 12500,
      content_niche: "Electronics and phone accessories",
      reason: "My audience asks for trusted phone and accessory sellers, so I can drive direct product sales.",
      payout_details: { provider: "mobile_money", account_name: "Kojo Boateng", account_number: "+233555000102" },
      terms_accepted: true
    }
  },
  {
    user: { email: "affiliate.approved@example.com", first_name: "Efua", last_name: "Owusu" },
    profile: {
      status: "approved",
      full_name: "Efua Owusu",
      phone: "+233555000103",
      country: "Ghana",
      city: "Accra",
      social_links: [ "https://instagram.com/efuafinds" ],
      promotion_channels: [ "Instagram", "YouTube" ],
      audience_size: 22000,
      content_niche: "Fashion and beauty",
      reason: "I publish styling content and can feature products in shopping guides.",
      payout_details: { provider: "mobile_money", account_name: "Efua Owusu", account_number: "+233555000103" },
      terms_accepted: true,
      reviewed_at: 3.days.ago
    }
  },
  {
    user: { email: "affiliate.rejected.cooldown@example.com", first_name: "Issah", last_name: "Yakubu" },
    profile: {
      status: "rejected",
      full_name: "Issah Yakubu",
      phone: "+233555000104",
      country: "Ghana",
      city: "Wa",
      social_links: [ "https://instagram.com/issahmarket" ],
      promotion_channels: [ "Instagram" ],
      audience_size: 140,
      content_niche: "General market deals",
      reason: "I want to try affiliate sales with my page.",
      payout_details: { provider: "mobile_money", account_name: "Issah Yakubu", account_number: "+233555000104" },
      terms_accepted: true,
      rejection_reason: "Audience and sales plan need more detail.",
      reviewed_at: 5.days.ago
    }
  },
  {
    user: { email: "affiliate.rejected.ready@example.com", first_name: "Adwoa", last_name: "Sarpong" },
    profile: {
      status: "rejected",
      full_name: "Adwoa Sarpong",
      phone: "+233555000105",
      country: "Ghana",
      city: "Kumasi",
      social_links: [ "https://tiktok.com/@adwoashop" ],
      promotion_channels: [ "TikTok", "WhatsApp" ],
      audience_size: 900,
      content_niche: "Kitchen and household items",
      reason: "I have improved my posting plan and want to reapply.",
      payout_details: { provider: "mobile_money", account_name: "Adwoa Sarpong", account_number: "+233555000105" },
      terms_accepted: true,
      rejection_reason: "Initial application did not explain promotion channels.",
      reviewed_at: 20.days.ago
    }
  }
]

customer_role = Role.find_by!(name: "CUSTOMER")
affiliate_role = Role.find_by!(name: "AFFILIATE")
admin_reviewer = User.joins(:role).find_by(roles: { name: [ "ADMIN", "SUPER_ADMIN" ] })

affiliate_seed_profiles.each do |seed|
  user = User.find_or_initialize_by(email: seed[:user][:email])
  user.assign_attributes(
    first_name: seed[:user][:first_name],
    last_name: seed[:user][:last_name],
    password: "password123",
    password_confirmation: "password123",
    role: seed[:profile][:status] == "approved" ? affiliate_role : customer_role
  )
  user.save!

  profile = user.affiliate_profile || user.build_affiliate_profile
  profile.assign_attributes(seed[:profile].merge(email: user.email))
  profile.reviewed_by = admin_reviewer if profile.status != "pending" && admin_reviewer
  profile.save!
end

puts "Seeded #{AffiliateProfile.count} affiliate profiles"

donald = User.find_or_initialize_by(email: "donaldakite00@gmail.com")
donald.assign_attributes(
  first_name: "Donald",
  last_name: "Akite",
  role: affiliate_role,
  phone_numbers: [ "233555002000" ]
)
if donald.new_record? || donald.encrypted_password.blank?
  donald.password = "password123"
  donald.password_confirmation = "password123"
end
donald.save!

donald_profile = donald.affiliate_profile || donald.build_affiliate_profile
donald_profile.assign_attributes(
  status: "approved",
  full_name: "Donald Akite",
  email: donald.email,
  phone: "233555002000",
  country: "Ghana",
  city: "Accra",
  social_links: [
    "https://tiktok.com/@donaldakite",
    "https://instagram.com/donaldakite"
  ],
  promotion_channels: [ "TikTok", "Instagram", "WhatsApp", "Product reviews" ],
  audience_size: 18500,
  content_niche: "Home, lifestyle, and plant care",
  reason: "I create product discovery content and drive buyers through short-form reviews and WhatsApp communities.",
  payout_details: {
    provider: "mobile_money",
    account_name: "Donald Akite",
    phone_number: "233555002000",
    country: "Ghana"
  },
  terms_accepted: true,
  reviewed_by: admin_reviewer,
  reviewed_at: 10.days.ago,
  rejection_reason: nil,
  suspended_at: nil
)
donald_profile.save!

AffiliateSetting.current.update!(
  signup_referral_enabled: true,
  signup_referral_percentage: 8,
  signup_referral_cap_amount: 25
)

warehouse = Warehouse.find_or_create_by!(name: "Affiliate Demo Warehouse") do |record|
  record.latitude = 5.6037
  record.longitude = -0.1870
  record.country = "Ghana"
  record.region = "Greater Accra"
  record.city = "Accra"
  record.address = { street: "Affiliate Demo Street" }
end

def seed_affiliate_product!(name:, price:, commission:, warehouse:)
  product = Product.find_or_initialize_by(name: name)
  product.assign_attributes(
    description: "#{name} for affiliate demo orders.",
    bookable_type: "unit",
    active: true,
    affiliate_commission_amount: commission,
    shipping_type: "bulk",
    weight_class: "medium",
    search_keywords: [ "affiliate", "demo", name.downcase ]
  )
  product.save!

  variant_type = product.variant_types.find_or_create_by!(name: "Base") do |record|
    record.pricing_role = "base"
  end
  variant_type.update!(pricing_role: "base") if variant_type.pricing_role != "base"

  option = variant_type.variant_options.find_or_initialize_by(name: "Default")
  option.assign_attributes(price: price)
  option.save!

  stock = VariantStock.find_or_initialize_by(product: product, warehouse: warehouse, option_ids: [ option.id ])
  stock.quantity = [ stock.quantity.to_i, 50 ].max
  stock.save!

  [ product, stock ]
end

demo_products = [
  seed_affiliate_product!(name: "Affiliate Demo Peace Lily", price: 160, commission: 14, warehouse: warehouse),
  seed_affiliate_product!(name: "Affiliate Demo Ceramic Planter", price: 95, commission: 9, warehouse: warehouse),
  seed_affiliate_product!(name: "Affiliate Demo Plant Care Kit", price: 120, commission: 11, warehouse: warehouse)
]

demo_buyers = [
  [ "akua.affiliate.demo@example.com", "Akua", "Mensah" ],
  [ "kwame.affiliate.demo@example.com", "Kwame", "Boateng" ],
  [ "esi.affiliate.demo@example.com", "Esi", "Owusu" ],
  [ "yaw.affiliate.demo@example.com", "Yaw", "Asare" ],
  [ "abena.affiliate.demo@example.com", "Abena", "Sarpong" ]
].each_with_index.map do |(email, first_name, last_name), index|
  buyer = User.find_or_initialize_by(email: email)
  buyer.assign_attributes(
    first_name: first_name,
    last_name: last_name,
    role: customer_role,
    phone_numbers: [ "23355510#{index.to_s.rjust(3, "0")}" ]
  )
  if buyer.new_record? || buyer.encrypted_password.blank?
    buyer.password = "password123"
    buyer.password_confirmation = "password123"
  end
  buyer.save!

  buyer.customer_addresses.find_or_create_by!(name: "#{first_name} Home") do |address|
    address.country = "Ghana"
    address.region = "Greater Accra"
    address.city = "Accra"
    address.latitude = 5.6037
    address.longitude = -0.1870
    address.address = { street: "#{first_name} Demo Street" }
    address.is_default = true
  end

  buyer
end

extra_demo_buyers = 20.times.map do |index|
  email = "donald.demo.buyer#{index.to_s.rjust(2, "0")}@example.com"
  buyer = User.find_or_initialize_by(email: email)
  buyer.assign_attributes(
    first_name: "Demo#{index + 1}",
    last_name: "Buyer",
    role: customer_role,
    phone_numbers: [ "23355620#{index.to_s.rjust(3, "0")}" ]
  )
  if buyer.new_record? || buyer.encrypted_password.blank?
    buyer.password = "password123"
    buyer.password_confirmation = "password123"
  end
  buyer.save!

  buyer.customer_addresses.find_or_create_by!(name: "Demo#{index + 1} Home") do |address|
    address.country = "Ghana"
    address.region = "Greater Accra"
    address.city = "Accra"
    address.latitude = 5.6037
    address.longitude = -0.1870
    address.address = { street: "Demo #{index + 1} Affiliate Street" }
    address.is_default = true
  end

  buyer
end

all_demo_buyers = demo_buyers + extra_demo_buyers

all_demo_buyers.each_with_index do |buyer, buyer_index|
  demo_products.each_with_index do |(product, _stock), product_index|
    visitor_id = "donald-demo-visitor-#{buyer_index + 1}-#{product_index + 1}"
    click = AffiliateClick.find_or_create_by!(
      affiliate_user: donald,
      buyer_user: buyer,
      product: product,
      visitor_id: visitor_id
    ) do |record|
      record.clicked_at = (12 - buyer_index - product_index).days.ago
      record.referrer = "https://tiktok.com/@donaldakite/video/#{buyer_index}#{product_index}"
      record.user_agent = "Seeded affiliate demo"
      record.ip_hash = Digest::SHA256.hexdigest("seed:donald:#{buyer_index}:#{product_index}")
    end

    AffiliateAttribution.find_or_create_by!(
      product: product,
      buyer_user: buyer
    ) do |record|
      record.affiliate_user = donald
      record.affiliate_click = click
      record.visitor_id = visitor_id
      record.attributed_at = click.clicked_at
      record.expires_at = 30.days.from_now
    end
  end
end

3.times do |index|
  referred_user = demo_buyers[index]
  AffiliateSignupReferral.find_or_create_by!(referred_user: referred_user) do |record|
    record.affiliate_user = donald
    record.visitor_id = "donald-signup-demo-#{index + 1}"
    record.referred_at = (9 - index).days.ago
  end
end

seeded_orders = [
  { order_id: "DON001A", buyer: demo_buyers[0], product_index: 0, quantity: 2, status: "available", created_at: 8.days.ago },
  { order_id: "DON002A", buyer: demo_buyers[1], product_index: 1, quantity: 1, status: "available", created_at: 6.days.ago },
  { order_id: "DON003A", buyer: demo_buyers[2], product_index: 2, quantity: 3, status: "pending", created_at: 4.days.ago },
  { order_id: "DON004A", buyer: demo_buyers[3], product_index: 0, quantity: 1, status: "pending", created_at: 2.days.ago },
  { order_id: "DON005A", buyer: demo_buyers[4], product_index: 1, quantity: 2, status: "available", created_at: 1.day.ago }
] + 30.times.map do |index|
  {
    order_id: "DONP#{(index + 1).to_s.rjust(3, "0")}",
    buyer: all_demo_buyers[index % all_demo_buyers.length],
    product_index: index % demo_products.length,
    quantity: (index % 3) + 1,
    status: index % 4 == 0 ? "pending" : "available",
    created_at: (35 - index).hours.ago
  }
end

seeded_orders.each do |seed|
  product, stock = demo_products[seed[:product_index]]
  item_price = stock.price
  total = item_price * seed[:quantity]
  order = Order.find_or_initialize_by(order_id: seed[:order_id])
  order.assign_attributes(
    user: seed[:buyer],
    status: "received",
    payment_status: "completed",
    customer_address: seed[:buyer].customer_addresses.default.first || seed[:buyer].customer_addresses.first,
    item_subtotal: total,
    total_amount: total,
    delivery_fee: 0,
    delivery_address_name: "#{seed[:buyer].first_name} Home",
    phones: seed[:buyer].phone_numbers,
    created_at: seed[:created_at],
    updated_at: seed[:created_at]
  )
  if order.order_items.empty?
    order.order_items.build(
      variant_stock: stock,
      quantity: seed[:quantity],
      variant_stock_price: item_price,
      variant_stock_quantity: stock.quantity,
      variant_stock_option_names: "Default",
      variant_stock_warehouse_name: warehouse.name
    )
  end
  order.save!
  order.transactions.find_or_initialize_by(provider_reference: "SEED-ORDER-#{order.order_id}").tap do |transaction|
    transaction.assign_attributes(
      user: order.user,
      amount_kobo: (order.total_price.to_d * 100).to_i,
      currency: "GHS",
      status: "success",
      provider: "seed",
      purpose: "order_payment",
      direction: "credit",
      processed_at: seed[:created_at],
      created_at: seed[:created_at],
      updated_at: Time.current,
      metadata: { "source" => "donald_affiliate_demo_seed" }
    )
    transaction.save!
  end
  AffiliateCommissionService.create_for_order!(order)

  order.affiliate_earnings.where(affiliate_user: donald).update_all(
    status: seed[:status],
    available_at: seed[:status] == "available" ? seed[:created_at] + 2.days : nil,
    earned_at: seed[:created_at],
    created_at: seed[:created_at],
    updated_at: Time.current
  )
end

donald.affiliate_earnings.where(status: "available").order(:earned_at).limit(1).update_all(status: "withdrawn", withdrawn_at: 12.hours.ago, updated_at: Time.current)

donald.affiliate_withdrawals.find_each do |withdrawal|
  withdrawal.payout_transaction&.destroy!
  withdrawal.destroy!
end

[
  { amount: 20, status: "paid", requested_at: 5.days.ago, reviewed_at: 4.days.ago, paid_at: 3.days.ago },
  { amount: 15, status: "pending", requested_at: 18.hours.ago },
  { amount: 8, status: "rejected", requested_at: 7.days.ago, reviewed_at: 6.days.ago, admin_note: "Demo rejected withdrawal." }
].each_with_index do |seed, index|
  withdrawal = donald.affiliate_withdrawals.build
  withdrawal.assign_attributes(
    amount: seed[:amount],
    currency: "GHS",
    status: seed[:status],
    payout_details: donald_profile.payout_details,
    reviewed_by: seed[:reviewed_at] ? admin_reviewer : nil,
    reviewed_at: seed[:reviewed_at],
    paid_at: seed[:paid_at],
    admin_note: seed[:admin_note] || "Seeded Donald affiliate demo withdrawal #{index + 1}"
  )
  withdrawal.save!
  next unless seed[:status] == "paid"

  withdrawal.create_payout_transaction!(
    user: donald,
    amount_kobo: (withdrawal.amount.to_d * 100).to_i,
    currency: withdrawal.currency,
    status: "success",
    provider: "seed",
    provider_reference: "SEED-WITHDRAWAL-#{withdrawal.id}",
    purpose: "affiliate_withdrawal_payout",
    direction: "debit",
    processed_at: seed[:paid_at],
    metadata: { "source" => "donald_affiliate_demo_seed" }
  )
end

puts "Seeded Donald affiliate demo data: #{donald.affiliate_clicks.count} clicks, #{donald.affiliate_earnings.count} earnings, #{donald.affiliate_withdrawals.count} withdrawals"
