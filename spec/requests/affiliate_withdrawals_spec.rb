require "rails_helper"

RSpec.describe "Affiliate withdrawals", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:buyer) { create(:user) }
  let(:profile) do
    create(
      :affiliate_profile,
      social_links: [ "https://instagram.com/withdrawals-affiliate" ],
      payout_details: {
        "provider" => "mtn",
        "account_name" => "Ama Mensah",
        "phone_number" => "233555000000",
        "country" => "Ghana"
      }
    )
  end
  let(:affiliate) do
    profile.approve!(admin)
    profile.user
  end

  it "creates a pending withdrawal and reserves available balance" do
    create(:affiliate_earning, affiliate_user: affiliate, buyer_user: buyer, status: "available", commission_amount: 20)

    post "/api/v1/affiliate_withdrawals", params: {
      affiliate_withdrawal: {
        amount: 12
      }
    }, headers: auth_headers(affiliate)

    expect(response).to have_http_status(:created)
    expect(json_response.dig("data", "attributes")).to include(
      "amount" => 12.0,
      "status" => "pending"
    )
    summary = json_response.dig("meta", "summary")
    expect(summary["available_balance"]).to eq(8.0)
    expect(summary["reserved_withdrawals"]).to eq(12.0)
  end

  it "requires complete payout settings before withdrawal" do
    profile.update!(payout_details: {})
    create(:affiliate_earning, affiliate_user: affiliate, buyer_user: buyer, status: "available", commission_amount: 20)

    post "/api/v1/affiliate_withdrawals", params: {
      affiliate_withdrawal: {
        amount: 12
      }
    }, headers: auth_headers(affiliate)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json_response["error"]).to eq("Complete payout settings before requesting a withdrawal")
  end

  it "rejects amounts at or below the minimum" do
    create(:affiliate_earning, affiliate_user: affiliate, buyer_user: buyer, status: "available", commission_amount: 20)

    post "/api/v1/affiliate_withdrawals", params: {
      affiliate_withdrawal: {
        amount: 1
      }
    }, headers: auth_headers(affiliate)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json_response["error"]).to eq("Withdrawal amount must be greater than GHS 1.00")
  end
end
