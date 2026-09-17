FactoryBot.define do
  factory :affiliate_profile do
    association :user, factory: [ :user, :affiliate ]
    status { "pending" }
    full_name { "#{user.first_name} #{user.last_name}" }
    email { user.email }
    phone { "+233555000000" }
    country { "Ghana" }
    city { "Accra" }
    social_links { [ "https://instagram.com/example" ] }
    promotion_channels { [ "Instagram" ] }
    audience_size { 1000 }
    content_niche { "Plants and lifestyle" }
    reason { "I want to promote products to my audience." }
    payout_details { { "provider" => "mobile_money", "account" => "+233555000000" } }
    terms_accepted { true }
  end
end
