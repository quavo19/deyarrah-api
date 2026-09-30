require "rails_helper"

RSpec.describe "Affiliate clicks", type: :request do
  let(:product) { create(:product, active: true) }
  let(:affiliate_profile) { create(:affiliate_profile, status: "approved", social_links: [ "https://instagram.com/affiliate-one" ]) }
  let(:admin) { create(:user, :admin) }

  before do
    affiliate_profile.approve!(admin)
  end

  def click_payload(code: affiliate_profile.affiliate_code, visitor_id: "visitor-123")
    {
      affiliate_click: {
        affiliate_code: code,
        product_id: product.id,
        visitor_id: visitor_id,
        landing_url: "https://shop.test/products/#{product.id}?ref=#{code}",
        referrer_url: "https://social.test/post"
      }
    }
  end

  it "records a click and creates first attribution for an anonymous visitor" do
    post "/api/v1/affiliate_clicks", params: click_payload

    expect(response).to have_http_status(:created)
    expect(json_response.dig("data", "attributes", "recorded")).to eq(true)
    expect(json_response.dig("data", "attributes", "attributed")).to eq(true)
    expect(AffiliateClick.count).to eq(1)
    expect(AffiliateAttribution.count).to eq(1)
    expect(AffiliateAttribution.first.affiliate_user).to eq(affiliate_profile.user)
  end

  it "does not record repeat clicks for the same affiliate product and visitor" do
    post "/api/v1/affiliate_clicks", params: click_payload
    post "/api/v1/affiliate_clicks", params: click_payload

    expect(response).to have_http_status(:created)
    expect(json_response.dig("data", "attributes", "recorded")).to eq(false)
    expect(AffiliateClick.count).to eq(1)
    expect(AffiliateAttribution.count).to eq(1)
  end

  it "does not record repeat clicks for the same affiliate product and ip address" do
    post "/api/v1/affiliate_clicks", params: click_payload(visitor_id: "visitor-one")
    post "/api/v1/affiliate_clicks", params: click_payload(visitor_id: "visitor-two")

    expect(response).to have_http_status(:created)
    expect(json_response.dig("data", "attributes", "recorded")).to eq(false)
    expect(AffiliateClick.count).to eq(1)
  end

  it "claims anonymous attribution when the visitor later signs in" do
    buyer = create(:user)

    post "/api/v1/affiliate_clicks", params: click_payload(visitor_id: "visitor-claim")
    post "/api/v1/affiliate_clicks", params: click_payload(visitor_id: "visitor-claim"), headers: auth_headers(buyer)

    expect(response).to have_http_status(:created)
    expect(AffiliateClick.count).to eq(1)
    expect(AffiliateAttribution.count).to eq(1)
    expect(AffiliateAttribution.first.buyer_user).to eq(buyer)
  end

  it "keeps first attribution when another affiliate link is clicked for the same product and visitor" do
    other_profile = create(:affiliate_profile, status: "approved", social_links: [ "https://instagram.com/affiliate-two" ])
    other_profile.approve!(admin)

    post "/api/v1/affiliate_clicks", params: click_payload
    post "/api/v1/affiliate_clicks", params: click_payload(code: other_profile.affiliate_code)

    expect(response).to have_http_status(:created)
    expect(json_response.dig("data", "attributes", "attributed")).to eq(false)
    expect(AffiliateClick.count).to eq(2)
    expect(AffiliateAttribution.count).to eq(1)
    expect(AffiliateAttribution.first.affiliate_user).to eq(affiliate_profile.user)
  end

  it "uses the logged-in buyer for attribution when authenticated" do
    buyer = create(:user)

    post "/api/v1/affiliate_clicks", params: click_payload(visitor_id: nil), headers: auth_headers(buyer)

    expect(response).to have_http_status(:created)
    attribution = AffiliateAttribution.first
    expect(attribution.buyer_user).to eq(buyer)
    expect(attribution.visitor_id).to be_nil
  end

  it "rejects inactive affiliate links" do
    pending_profile = create(:affiliate_profile, status: "pending")

    post "/api/v1/affiliate_clicks", params: click_payload(code: pending_profile.affiliate_code)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json_response["error"]).to eq("Affiliate link is not active")
  end

  it "rejects authenticated self-click attribution" do
    post "/api/v1/affiliate_clicks",
      params: click_payload(visitor_id: nil),
      headers: auth_headers(affiliate_profile.user)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json_response["error"]).to eq("Affiliates cannot track their own clicks")
    expect(AffiliateClick.count).to eq(0)
    expect(AffiliateAttribution.count).to eq(0)
  end
end
