FactoryBot.define do
  factory :affiliate_attribution do
    association :affiliate_user, factory: [ :user, :affiliate ]
    product
    visitor_id { SecureRandom.uuid }
    attributed_at { Time.current }
    expires_at { 30.days.from_now }
  end
end
