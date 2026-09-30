require "rails_helper"

RSpec.describe "Admin affiliate withdrawals", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:super_admin) { create(:user, :super_admin) }
  let(:profile) { create(:affiliate_profile, social_links: [ "https://instagram.com/admin-withdrawals-affiliate" ]) }
  let(:affiliate) do
    profile.approve!(super_admin)
    profile.user
  end

  it "lists withdrawal requests for admins" do
    withdrawal = create(:affiliate_withdrawal, affiliate_user: affiliate, amount: 15)

    get "/api/v1/affiliate_withdrawal_requests", headers: auth_headers(admin)

    expect(response).to have_http_status(:ok)
    expect(json_response["data"].first["id"]).to eq(withdrawal.id)
  end

  it "approves withdrawal requests for super admins" do
    withdrawal = create(:affiliate_withdrawal, affiliate_user: affiliate, status: "pending")

    post "/api/v1/affiliate_withdrawal_requests/#{withdrawal.id}/approve", headers: auth_headers(super_admin)

    expect(response).to have_http_status(:ok)
    expect(withdrawal.reload.status).to eq("approved")
    expect(withdrawal.reviewed_by).to eq(super_admin)
  end

  it "does not approve withdrawal requests for regular admins" do
    withdrawal = create(:affiliate_withdrawal, affiliate_user: affiliate, status: "pending")

    post "/api/v1/affiliate_withdrawal_requests/#{withdrawal.id}/approve", headers: auth_headers(admin)

    expect(response).to have_http_status(:forbidden)
    expect(json_response["error"]).to eq("Only super admins can approve affiliate withdrawals")
    expect(withdrawal.reload.status).to eq("pending")
  end

  it "initiates Paystack transfer for approved withdrawal requests" do
    withdrawal = create(
      :affiliate_withdrawal,
      affiliate_user: affiliate,
      status: "approved",
      payout_details: {
        "provider" => "mtn",
        "account_name" => "Ama Mensah",
        "phone_number" => "233555000000",
        "country" => "Ghana"
      }
    )
    allow(PaystackTransferService).to receive(:initiate_withdrawal!) do |request|
      request.update!(status: "paid", paid_at: Time.current)
      { "transfer_code" => "TRF_123" }
    end

    post "/api/v1/affiliate_withdrawal_requests/#{withdrawal.id}/pay", headers: auth_headers(admin)

    expect(response).to have_http_status(:ok)
    expect(json_response["message"]).to eq("Paystack transfer initiated")
    expect(withdrawal.reload.status).to eq("paid")
    expect(withdrawal.paid_at).to be_present
  end

  it "does not pay pending withdrawal requests before approval" do
    withdrawal = create(:affiliate_withdrawal, affiliate_user: affiliate, status: "pending")

    post "/api/v1/affiliate_withdrawal_requests/#{withdrawal.id}/pay", headers: auth_headers(admin)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json_response["error"]).to eq("Withdrawal must be approved before payment")
  end

  it "does not approve withdrawals for suspended affiliates" do
    withdrawal = create(:affiliate_withdrawal, affiliate_user: affiliate, status: "pending")
    profile.suspend!(super_admin, "Policy review")

    post "/api/v1/affiliate_withdrawal_requests/#{withdrawal.id}/approve", headers: auth_headers(super_admin)

    expect(response).to have_http_status(:forbidden)
    expect(json_response["error"]).to eq("Cannot approve withdrawal for a blocked or suspended affiliate")
  end

  it "does not pay withdrawals for blocked affiliates" do
    withdrawal = create(
      :affiliate_withdrawal,
      affiliate_user: affiliate,
      status: "approved",
      payout_details: {
        "provider" => "mtn",
        "account_name" => "Ama Mensah",
        "phone_number" => "233555000000",
        "country" => "Ghana"
      }
    )
    affiliate.update!(blocked: true)

    post "/api/v1/affiliate_withdrawal_requests/#{withdrawal.id}/pay", headers: auth_headers(admin)

    expect(response).to have_http_status(:forbidden)
    expect(json_response["error"]).to eq("Cannot pay withdrawal for a blocked or suspended affiliate")
  end
end
