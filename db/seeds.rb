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
