require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:buyer) { create(:user, email: "buyer@example.com") }

  it "lists payment ledger entries for admins" do
    order = create(:order, user: buyer)
    transaction = create(:transaction, order: order, user: buyer, status: "success", purpose: "order_payment")

    get "/api/v1/transactions", headers: auth_headers(admin)

    expect(response).to have_http_status(:ok)
    expect(json_response["data"].first["id"]).to eq(transaction.id)
    expect(json_response.dig("data", 0, "attributes")).to include(
      "user_email" => "buyer@example.com",
      "purpose" => "order_payment",
      "status" => "success"
    )
  end

  it "filters transactions by purpose" do
    create(:transaction, purpose: "order_payment")
    withdrawal = create(:affiliate_withdrawal, status: "approved")
    payout = create(
      :transaction,
      order: nil,
      user: withdrawal.affiliate_user,
      affiliate_withdrawal: withdrawal,
      purpose: "affiliate_withdrawal_payout",
      direction: "debit",
      provider_reference: "AFF-WD-#{withdrawal.id}"
    )

    get "/api/v1/transactions", params: { purpose: "affiliate_withdrawal_payout" }, headers: auth_headers(admin)

    expect(response).to have_http_status(:ok)
    expect(json_response["data"].map { |item| item["id"] }).to eq([ payout.id ])
  end
end
