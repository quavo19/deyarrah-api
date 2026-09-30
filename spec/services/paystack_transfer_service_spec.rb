require "rails_helper"

RSpec.describe PaystackTransferService do
  around do |example|
    old_secret = ENV["PAYSTACK_SECRET_KEY"]
    old_code = ENV["PAYSTACK_GH_MTN_MOMO_CODE"]
    ENV["PAYSTACK_SECRET_KEY"] = "sk_test_123"
    ENV["PAYSTACK_GH_MTN_MOMO_CODE"] = "MTN"
    example.run
  ensure
    ENV["PAYSTACK_SECRET_KEY"] = old_secret
    ENV["PAYSTACK_GH_MTN_MOMO_CODE"] = old_code
  end

  it "creates a mobile money recipient and initiates a transfer for a withdrawal" do
    withdrawal = build(
      :affiliate_withdrawal,
      id: SecureRandom.uuid,
      status: "approved",
      amount: 25,
      payout_details: {
        "provider" => "mtn",
        "account_name" => "Ama Mensah",
        "phone_number" => "233555000000",
        "country" => "Ghana"
      }
    )

    allow(described_class).to receive(:post).with("/transferrecipient", hash_including(
      type: "mobile_money",
      account_number: "233555000000",
      bank_code: "MTN",
      currency: "GHS"
    )).and_return({ "status" => true, "data" => { "recipient_code" => "RCP_123" } })
    allow(described_class).to receive(:post).with("/transfer", hash_including(
      source: "balance",
      amount: 2500,
      recipient: "RCP_123",
      reason: "Affiliate withdrawal"
    )).and_return({ "status" => true, "data" => { "transfer_code" => "TRF_123" } })

    withdrawal.save!

    described_class.initiate_withdrawal!(withdrawal)

    expect(withdrawal.reload.status).to eq("paid")
    expect(withdrawal.paid_at).to be_present
    expect(withdrawal.payout_transaction).to have_attributes(
      status: "success",
      purpose: "affiliate_withdrawal_payout",
      direction: "debit",
      provider_reference: "AFF-WD-#{withdrawal.id}"
    )
    expect(withdrawal.payout_details).to include(
      "paystack_recipient_code" => "RCP_123",
      "paystack_transfer_code" => "TRF_123"
    )
  end

  it "does not pay the same withdrawal twice" do
    withdrawal = create(
      :affiliate_withdrawal,
      status: "approved",
      amount: 25,
      payout_details: {
        "provider" => "mtn",
        "account_name" => "Ama Mensah",
        "phone_number" => "233555000000",
        "country" => "Ghana"
      }
    )
    create(
      :transaction,
      order: nil,
      user: withdrawal.affiliate_user,
      affiliate_withdrawal: withdrawal,
      amount_kobo: 2500,
      status: "success",
      provider_reference: "AFF-WD-#{withdrawal.id}",
      purpose: "affiliate_withdrawal_payout",
      direction: "debit"
    )

    expect { described_class.initiate_withdrawal!(withdrawal) }
      .to raise_error(described_class::PaystackTransferError, "Withdrawal has already been paid")
  end
end
