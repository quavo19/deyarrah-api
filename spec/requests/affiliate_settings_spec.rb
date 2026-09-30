require "rails_helper"

RSpec.describe "Affiliate settings", type: :request do
  let(:admin) { create(:user, :admin) }

  it "returns current signup referral settings" do
    AffiliateSetting.current.update!(signup_referral_percentage: 12.5, signup_referral_cap_amount: 30)

    get "/api/v1/affiliate_settings"

    expect(response).to have_http_status(:ok)
    expect(json_response.dig("data", "attributes")).to include(
      "signup_referral_percentage" => 12.5,
      "signup_referral_cap_amount" => 30.0,
      "signup_referral_enabled" => true
    )
  end

  it "lets admins update signup referral settings" do
    patch "/api/v1/affiliate_settings", params: {
      affiliate_settings: {
        signup_referral_percentage: 8,
        signup_referral_cap_amount: 20,
        signup_referral_enabled: false
      }
    }, headers: auth_headers(admin)

    expect(response).to have_http_status(:ok)
    expect(AffiliateSetting.current).to have_attributes(
      signup_referral_percentage: BigDecimal("8"),
      signup_referral_cap_amount: BigDecimal("20"),
      signup_referral_enabled: false
    )
  end
end
