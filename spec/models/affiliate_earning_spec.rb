require "rails_helper"

RSpec.describe AffiliateEarning, type: :model do
  it "requires a supported status" do
    earning = build(:affiliate_earning, status: "unknown")

    expect(earning).not_to be_valid
    expect(earning.errors[:status]).to be_present
  end

  it "requires a non-negative commission amount" do
    earning = build(:affiliate_earning, commission_amount: -1)

    expect(earning).not_to be_valid
    expect(earning.errors[:commission_amount]).to be_present
  end

  it "sets earned_at by default" do
    earning = build(:affiliate_earning, earned_at: nil)

    expect(earning).to be_valid
    expect(earning.earned_at).to be_present
  end

  it "does not allow suspended affiliates to receive earnings" do
    profile = create(:affiliate_profile, status: "approved")
    profile.approve!(create(:user, :admin))
    profile.suspend!(create(:user, :admin), "Policy violation")

    earning = build(:affiliate_earning, affiliate_user: profile.user)

    expect(earning).not_to be_valid
    expect(earning.errors[:affiliate_user]).to include("must be an active affiliate")
  end
end
