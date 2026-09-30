require "rails_helper"

RSpec.describe "Affiliate payout settings", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:profile) { create(:affiliate_profile, social_links: [ "https://instagram.com/payout-settings" ]) }
  let(:affiliate) do
    profile.approve!(admin)
    profile.user
  end

  it "lets an approved affiliate save mobile money payout details" do
    put "/api/v1/affiliate_payout_settings", params: {
      payout_details: {
        provider: "mtn",
        account_name: "Ama Mensah",
        phone_number: "0555000000",
        country: "Ghana"
      }
    }, headers: auth_headers(affiliate)

    expect(response).to have_http_status(:ok)
    attrs = json_response.dig("data", "attributes")
    expect(attrs).to include(
      "provider" => "mtn",
      "account_name" => "Ama Mensah",
      "phone_number" => "233555000000",
      "country" => "Ghana"
    )
  end

  it "rejects unsupported providers" do
    put "/api/v1/affiliate_payout_settings", params: {
      payout_details: {
        provider: "bank",
        account_name: "Ama Mensah",
        phone_number: "233555000000",
        country: "Ghana"
      }
    }, headers: auth_headers(affiliate)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json_response["errors"]).to include("Provider is required")
  end
end
