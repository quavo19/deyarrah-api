require "rails_helper"

RSpec.describe AffiliateClick, type: :model do
  it "requires a buyer user or visitor id" do
    click = build(:affiliate_click, buyer_user: nil, visitor_id: nil)

    expect(click).not_to be_valid
    expect(click.errors[:base]).to include("must include a buyer user or visitor id")
  end

  it "sets clicked_at by default" do
    click = build(:affiliate_click, clicked_at: nil)

    expect(click).to be_valid
    expect(click.clicked_at).to be_present
  end

  it "does not allow suspended affiliates to track clicks" do
    profile = create(:affiliate_profile, status: "approved")
    profile.approve!(create(:user, :admin))
    profile.suspend!(create(:user, :admin), "Policy violation")

    click = build(:affiliate_click, affiliate_user: profile.user)

    expect(click).not_to be_valid
    expect(click.errors[:affiliate_user]).to include("must be an active affiliate")
  end
end
