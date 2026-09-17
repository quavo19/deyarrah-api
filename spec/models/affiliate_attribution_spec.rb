require "rails_helper"

RSpec.describe AffiliateAttribution, type: :model do
  it "requires a buyer user or visitor id" do
    attribution = build(:affiliate_attribution, buyer_user: nil, visitor_id: nil)

    expect(attribution).not_to be_valid
    expect(attribution.errors[:base]).to include("must include a buyer user or visitor id")
  end

  it "sets a default 30 day tracking window" do
    attribution = build(:affiliate_attribution, attributed_at: nil, expires_at: nil)

    expect(attribution).to be_valid
    expect(attribution.attributed_at).to be_present
    expect(attribution.expires_at).to be_within(1.second).of(attribution.attributed_at + 30.days)
  end

  it "does not allow suspended affiliates to receive attributions" do
    profile = create(:affiliate_profile, status: "approved")
    profile.approve!(create(:user, :admin))
    profile.suspend!(create(:user, :admin), "Policy violation")

    attribution = build(:affiliate_attribution, affiliate_user: profile.user)

    expect(attribution).not_to be_valid
    expect(attribution.errors[:affiliate_user]).to include("must be an active affiliate")
  end
end
