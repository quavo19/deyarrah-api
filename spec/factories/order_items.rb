FactoryBot.define do
  factory :order_item do
    order
    quantity { 1 }
    variant_stock_price { 100.00 }
  end
end
