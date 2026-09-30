FactoryBot.define do
  factory :affiliate_signup_referral do
    association :affiliate_user, factory: [ :user, :affiliate ]
    association :referred_user, factory: :user
    visitor_id { SecureRandom.uuid }
    referred_at { Time.current }
  end
end
