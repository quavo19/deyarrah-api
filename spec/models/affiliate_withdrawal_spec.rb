require "rails_helper"

RSpec.describe AffiliateWithdrawal, type: :model do
  it "requires a positive amount" do
    withdrawal = build(:affiliate_withdrawal, amount: 0)

    expect(withdrawal).not_to be_valid
    expect(withdrawal.errors[:amount]).to be_present
  end

  it "sets requested_at by default" do
    withdrawal = build(:affiliate_withdrawal, requested_at: nil)

    expect(withdrawal).to be_valid
    expect(withdrawal.requested_at).to be_present
  end

  it "does not allow suspended affiliates to request withdrawals" do
    profile = create(:affiliate_profile, status: "approved")
    profile.approve!(create(:user, :admin))
    profile.suspend!(create(:user, :admin), "Policy violation")

    withdrawal = build(:affiliate_withdrawal, affiliate_user: profile.user)

    expect(withdrawal).not_to be_valid
    expect(withdrawal.errors[:affiliate_user]).to include("must be an active affiliate")
  end
end
