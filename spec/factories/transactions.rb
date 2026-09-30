FactoryBot.define do
  factory :transaction do
    order
    user { order.user }
    amount_kobo { 10_000 }
    currency { "GHS" }
    status { "initialized" }
    provider { "paystack" }
    provider_reference { SecureRandom.uuid }
    purpose { "order_payment" }
    direction { "credit" }
    metadata { {} }
  end
end
