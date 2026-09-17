FactoryBot.define do
  factory :delivery_high_value_rate do
    pricing_zone { "near" }
    shipping_category { "phone" }
    fee { 100 }
  end
end
