FactoryBot.define do
  factory :affiliate_withdrawal do
    association :affiliate_user, factory: [ :user, :affiliate ]
    status { "pending" }
    amount { 10.00 }
    currency { "GHS" }
    payout_details { { "provider" => "mobile_money", "account" => "+233555000000" } }
    requested_at { Time.current }
  end
end
