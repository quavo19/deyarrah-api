require "rails_helper"

RSpec.describe AffiliateCommissionService do
  let(:admin) { create(:user, :admin) }
  let(:buyer) { create(:user) }
  let(:affiliate_profile) do
    create(:affiliate_profile, social_links: [ "https://instagram.com/affiliate-#{SecureRandom.hex(4)}" ])
  end
  let(:affiliate_user) do
    affiliate_profile.approve!(admin)
    affiliate_profile.user
  end

  def approved_affiliate(label)
    profile = create(:affiliate_profile, social_links: [ "https://instagram.com/#{label}-#{SecureRandom.hex(4)}" ])
    profile.approve!(admin)
    profile.user
  end

  def stocked_product(commission: 12.5, price: 100)
    product = create(:product, affiliate_commission_amount: commission)
    warehouse = Warehouse.create!(
      name: "Affiliate Test Warehouse #{SecureRandom.hex(3)}",
      latitude: 5.6037,
      longitude: -0.1870,
      country: "Ghana",
      region: "Greater Accra",
      city: "Accra"
    )
    variant_type = VariantType.create!(product: product, name: "Base", pricing_role: "base")
    variant_option = VariantOption.create!(variant_type: variant_type, name: "Default", price: price)
    variant_stock = VariantStock.create!(
      product: product,
      warehouse: warehouse,
      quantity: 10,
      option_ids: [ variant_option.id ]
    )

    [ product, variant_stock ]
  end

  def order_for(product:, variant_stock:, quantity: 1, status: "pending", user: buyer)
    order = create(:order, user: user, status: status)
    order.order_items.destroy_all
    create(:order_item, order: order, variant_stock: variant_stock, quantity: quantity)
    order.reload
  end

  it "claims matching anonymous visitor attributions for order products" do
    product, variant_stock = stocked_product
    order = order_for(product: product, variant_stock: variant_stock)
    attribution = create(
      :affiliate_attribution,
      affiliate_user: affiliate_user,
      product: product,
      visitor_id: "visitor-123",
      buyer_user: nil
    )

    described_class.claim_visitor_attributions!(order, "visitor-123")

    expect(attribution.reload.buyer_user).to eq(buyer)
  end

  it "creates one pending earning when a referred order is received" do
    product, variant_stock = stocked_product(commission: 7.5, price: 80)
    order = order_for(product: product, variant_stock: variant_stock, quantity: 2)
    attribution = create(
      :affiliate_attribution,
      affiliate_user: affiliate_user,
      product: product,
      buyer_user: buyer,
      visitor_id: nil
    )

    order.update!(status: "received")

    earning = AffiliateEarning.find_by!(order_item: order.order_items.first)
    expect(earning).to have_attributes(
      affiliate_user: affiliate_user,
      buyer_user: buyer,
      order: order,
      product: product,
      affiliate_attribution: attribution,
      status: "pending",
      currency: "GHS"
    )
    expect(earning.commission_amount).to eq(BigDecimal("15.0"))
    expect(earning.sale_amount).to eq(BigDecimal("160.0"))
    expect(attribution.reload.converted_at).to be_present
  end

  it "does not create duplicate earnings when run more than once" do
    product, variant_stock = stocked_product(commission: 5)
    order = order_for(product: product, variant_stock: variant_stock, status: "received")
    create(:affiliate_attribution, affiliate_user: affiliate_user, product: product, buyer_user: buyer, visitor_id: nil)

    described_class.create_for_order!(order)
    described_class.create_for_order!(order)

    expect(AffiliateEarning.where(order_item: order.order_items.first).count).to eq(1)
  end

  it "pays different affiliates for different referred products in one order" do
    first_product, first_stock = stocked_product(commission: 5, price: 50)
    second_product, second_stock = stocked_product(commission: 8, price: 75)
    second_affiliate = approved_affiliate("affiliate-two")
    order = order_for(product: first_product, variant_stock: first_stock)
    create(:order_item, order: order, variant_stock: second_stock, quantity: 3)
    create(:affiliate_attribution, affiliate_user: affiliate_user, product: first_product, buyer_user: buyer, visitor_id: nil)
    create(:affiliate_attribution, affiliate_user: second_affiliate, product: second_product, buyer_user: buyer, visitor_id: nil)

    order.update!(status: "received")

    earnings = AffiliateEarning.order(:commission_amount)
    expect(earnings.map(&:affiliate_user)).to match_array([ affiliate_user, second_affiliate ])
    expect(earnings.map(&:product)).to match_array([ first_product, second_product ])
    expect(earnings.map(&:commission_amount)).to match_array([ BigDecimal("5.0"), BigDecimal("24.0") ])
  end

  it "skips products with no commission" do
    product, variant_stock = stocked_product(commission: 0)
    order = order_for(product: product, variant_stock: variant_stock, status: "received")
    create(:affiliate_attribution, affiliate_user: affiliate_user, product: product, buyer_user: buyer, visitor_id: nil)

    described_class.create_for_order!(order)

    expect(AffiliateEarning.count).to eq(0)
  end

  it "skips self referrals" do
    product, variant_stock = stocked_product(commission: 10)
    order = order_for(product: product, variant_stock: variant_stock, status: "received", user: affiliate_user)
    create(:affiliate_attribution, affiliate_user: affiliate_user, product: product, buyer_user: affiliate_user, visitor_id: nil)

    described_class.create_for_order!(order)

    expect(AffiliateEarning.count).to eq(0)
  end

  it "creates signup referral earnings for only the first three received orders" do
    AffiliateSetting.current.update!(signup_referral_percentage: 10, signup_referral_cap_amount: 15, signup_referral_enabled: true)
    referral = create(:affiliate_signup_referral, affiliate_user: affiliate_user, referred_user: buyer)

    4.times do
      product, variant_stock = stocked_product(commission: 0, price: 200)
      order = order_for(product: product, variant_stock: variant_stock, status: "pending")
      order.update!(status: "received")
    end

    signup_earnings = AffiliateEarning.where(affiliate_signup_referral: referral)
    expect(signup_earnings.count).to eq(3)
    expect(signup_earnings.pluck(:earning_type).uniq).to eq([ "signup_referral" ])
    expect(signup_earnings.map(&:commission_amount)).to all(eq(BigDecimal("15.0")))
    expect(referral.reload.rewarded_orders_count).to eq(3)
  end

  it "cancels pending and available earnings when a received order is returned" do
    product, variant_stock = stocked_product(commission: 10, price: 100)
    order = order_for(product: product, variant_stock: variant_stock, quantity: 1)
    create(:affiliate_attribution, affiliate_user: affiliate_user, product: product, buyer_user: buyer, visitor_id: nil)

    order.update!(status: "received")
    earning = AffiliateEarning.find_by!(order: order)
    earning.update!(status: "available", available_at: Time.current)

    order.update!(status: "returning")

    expect(earning.reload.status).to eq("cancelled")
  end

  it "does not cancel already withdrawn earnings when an order is cancelled" do
    product, variant_stock = stocked_product(commission: 10, price: 100)
    order = order_for(product: product, variant_stock: variant_stock, quantity: 1)
    create(:affiliate_attribution, affiliate_user: affiliate_user, product: product, buyer_user: buyer, visitor_id: nil)

    order.update!(status: "received")
    earning = AffiliateEarning.find_by!(order: order)
    earning.update!(status: "withdrawn", withdrawn_at: Time.current)

    order.update!(status: "cancelled")

    expect(earning.reload.status).to eq("withdrawn")
  end
end
