FactoryBot.define do
  factory :delivery_setting do
    key { "high_value_additional_unit_multiplier" }
    value { { multiplier: 0.75 } }
  end
end
