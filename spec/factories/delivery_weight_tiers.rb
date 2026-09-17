FactoryBot.define do
  factory :delivery_weight_tier do
    pricing_zone { "near" }
    min_weight_kg { 0 }
    max_weight_kg { 5 }
    fee { 20 }
  end
end
