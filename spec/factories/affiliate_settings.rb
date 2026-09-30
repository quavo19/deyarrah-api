FactoryBot.define do
  factory :affiliate_setting do
    signup_referral_percentage { 10.0 }
    signup_referral_cap_amount { 25.0 }
    signup_referral_enabled { true }
  end
end
