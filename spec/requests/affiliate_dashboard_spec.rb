require "rails_helper"

RSpec.describe "Affiliate dashboard", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:buyer) { create(:user) }
  let(:profile) { create(:affiliate_profile, social_links: [ "https://instagram.com/dashboard-affiliate" ]) }
  let(:affiliate) do
    profile.approve!(admin)
    profile.user
  end

  it "returns summary totals and recent earnings for the approved affiliate" do
    create(:affiliate_click, affiliate_user: affiliate, buyer_user: buyer, visitor_id: nil)
    first_product = create(:product, name: "Peace Lily")
    second_product = create(:product, name: "Snake Plant")
    create(:affiliate_earning, affiliate_user: affiliate, buyer_user: buyer, product: first_product, status: "pending", commission_amount: 12.5, sale_amount: 100)
    create(:affiliate_earning, affiliate_user: affiliate, buyer_user: buyer, product: second_product, status: "available", commission_amount: 7.5, sale_amount: 80)
    create(:affiliate_earning, affiliate_user: affiliate, buyer_user: buyer, status: "cancelled", commission_amount: 99, sale_amount: 100)
    create(:affiliate_earning, affiliate_user: create(:user, :affiliate), buyer_user: buyer, commission_amount: 55)

    get "/api/v1/affiliate_dashboard", headers: auth_headers(affiliate)

    expect(response).to have_http_status(:ok)
    summary = json_response.dig("data", "attributes", "summary")
    expect(summary).to include(
      "total_clicks" => 1,
      "total_referred_orders" => 2,
      "total_earned" => 20.0,
      "pending_balance" => 12.5,
      "available_balance" => 7.5,
      "withdrawn_balance" => 0.0
    )
    recent = json_response.dig("data", "attributes", "recent_earnings")
    expect(recent.size).to eq(2)
    expect(recent.map { |item| item.dig("attributes", "product_name") }).to contain_exactly("Peace Lily", "Snake Plant")
    expect(recent.first.dig("attributes", "buyer_user_id")).to be_nil
  end

  it "rejects affiliates that are not approved" do
    pending_profile = create(:affiliate_profile, status: "pending")

    get "/api/v1/affiliate_dashboard", headers: auth_headers(pending_profile.user)

    expect(response).to have_http_status(:forbidden)
  end

  it "paginates recent earnings" do
    12.times do |index|
      create(
        :affiliate_earning,
        affiliate_user: affiliate,
        buyer_user: buyer,
        commission_amount: index + 1,
        earned_at: index.days.ago
      )
    end

    get "/api/v1/affiliate_dashboard", params: { page: 2, per_page: 5 }, headers: auth_headers(affiliate)

    expect(response).to have_http_status(:ok)
    attrs = json_response.dig("data", "attributes")
    expect(attrs["recent_earnings"].size).to eq(5)
    expect(attrs["recent_earnings_meta"]).to include(
      "current_page" => 2,
      "per_page" => 5,
      "total_count" => 12,
      "total_pages" => 3
    )
  end
end
