FactoryBot.define do
  factory :order do
    user
    status { "pending" }
    payment_status { "pending" }

    after(:build) do |order|
      order.order_items.build(quantity: 1, variant_stock_price: 100.00) if order.order_items.empty?
    end
  end
end
