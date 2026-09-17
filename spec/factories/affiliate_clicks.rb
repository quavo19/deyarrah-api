FactoryBot.define do
  factory :affiliate_click do
    association :affiliate_user, factory: [ :user, :affiliate ]
    product
    visitor_id { SecureRandom.uuid }
    clicked_at { Time.current }
  end
end
