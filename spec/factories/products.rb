FactoryBot.define do
  factory :product do
    name { "Peace Lily" }
    description { "Indoor plant" }
    bookable_type { "unit" }
    active { true }
    affiliate_commission_amount { 0.0 }
    bonus_points { 0 }
    shipping_type { "bulk" }
    weight_class { "medium" }
    search_keywords { [] }
  end
end
