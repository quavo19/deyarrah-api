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
end
