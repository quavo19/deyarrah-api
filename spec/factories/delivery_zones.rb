FactoryBot.define do
  factory :delivery_zone do
    name { "Upper East - All Towns" }
    sequence(:code) { |n| "upper_east_all_towns_#{n}" }
    pricing_zone { "near" }
    region { "Upper East" }
    active { true }
  end
end
