require "rails_helper"

RSpec.describe DeliveryFeeCalculator do
  before do
    DeliveryZone.delete_all
    DeliveryWeightTier.delete_all
    DeliveryHighValueRate.delete_all
    DeliverySetting.delete_all

    create(:delivery_zone, pricing_zone: "near", region: "Upper East")
    create(:delivery_weight_tier, pricing_zone: "near", min_weight_kg: 0, max_weight_kg: 5, fee: 20)
    create(:delivery_weight_tier, pricing_zone: "near", min_weight_kg: 5, max_weight_kg: 15, fee: 50)
    create(:delivery_high_value_rate, pricing_zone: "near", shipping_category: "phone", fee: 100)
    create(:delivery_setting, value: { multiplier: 0.75 })
  end

  it "uses a bulk weight tier plus discounted high-value category quantity fees" do
    warehouse = Warehouse.create!(
      name: "Bolga Warehouse",
      latitude: 10.7856,
      longitude: -0.8514,
      country: "Ghana"
    )
    address = CustomerAddress.create!(
      user: create(:user),
      name: "Bolgatanga",
      country: "Ghana",
      region: "Upper East",
      city: "Bolgatanga"
    )
    order = Order.new(user: address.user, status: "pending", payment_status: "pending", customer_address: address)

    bulk_stock = variant_stock_for(
      warehouse: warehouse,
      product: create(:product, shipping_type: "bulk", weight_kg: 3, weight_class: "medium")
    )
    phone_stock = variant_stock_for(
      warehouse: warehouse,
      product: create(:product, shipping_type: "high_value", shipping_category: "phone")
    )

    order.order_items.build(variant_stock: bulk_stock, quantity: 2)
    order.order_items.build(variant_stock: phone_stock, quantity: 2)
    order.save!

    fulfillment = Fulfillment.create!(order: order, warehouse: warehouse)
    fulfillment.fulfillment_items.create!(order_item: order.order_items.first)
    fulfillment.fulfillment_items.create!(order_item: order.order_items.second)

    expect(described_class.new(fulfillment).calculate).to eq(BigDecimal("225.0"))
  end

  def variant_stock_for(warehouse:, product:)
    variant_type = VariantType.create!(product: product, name: "Base", pricing_role: "base")
    option = VariantOption.create!(variant_type: variant_type, name: SecureRandom.uuid, price: 100)
    VariantStock.create!(warehouse: warehouse, product: product, option_ids: [ option.id ], quantity: 10)
  end
end
