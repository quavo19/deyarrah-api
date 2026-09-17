FactoryBot.define do
  factory :affiliate_earning do
    association :affiliate_user, factory: [ :user, :affiliate ]
    buyer_user factory: :user
    product
    order
    order_item { order.order_items.first || association(:order_item, order: order) }
    status { "pending" }
    sale_amount { 100.00 }
    commission_amount { 10.00 }
    currency { "GHS" }
    earned_at { Time.current }
  end
end
