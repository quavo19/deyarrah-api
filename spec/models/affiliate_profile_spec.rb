require "rails_helper"

RSpec.describe AffiliateProfile, type: :model do
  it "generates an affiliate code when one is not provided" do
    profile = build(:affiliate_profile, affiliate_code: nil)

    expect(profile).to be_valid
    expect(profile.affiliate_code).to be_present
  end

  it "requires a supported status" do
    profile = build(:affiliate_profile, status: "unknown")

    expect(profile).not_to be_valid
    expect(profile.errors[:status]).to be_present
  end

  it "allows an application without a reason or payout details" do
    profile = build(:affiliate_profile, reason: "", payout_details: {})

    expect(profile).to be_valid
  end

  it "detects matching social links used by another application" do
    create(:affiliate_profile, full_name: "First Affiliate", social_links: [ "https://www.instagram.com/example/" ])
    profile = build(:affiliate_profile, social_links: [ "https://instagram.com/example" ])

    expect(profile.social_link_conflicts.first[:full_name]).to eq("First Affiliate")
    expect(profile.social_link_conflicts.first[:matching_links]).to include("instagram.com/example")
  end

  it "blocks approval when a social link is already used by another application" do
    create(:affiliate_profile, social_links: [ "https://www.tiktok.com/@samehandle" ])
    profile = create(:affiliate_profile, social_links: [ "https://www.tiktok.com/@samehandle/" ])
    reviewer = create(:user, :admin)

    expect { profile.approve!(reviewer) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(profile.errors[:social_links]).to include("are already used by another affiliate application")
  end
end
