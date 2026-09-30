require "rails_helper"

RSpec.describe "Affiliate signup referrals", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:profile) { create(:affiliate_profile, social_links: [ "https://instagram.com/signup-referrer" ]) }
  let(:affiliate) do
    profile.approve!(admin)
    profile.user
  end
  let(:referred_user) { create(:user) }

  before do
    affiliate
  end

  it "tracks the current user's signup referral from an affiliate code" do
    post "/api/v1/affiliate_signup_referrals", params: {
      affiliate_signup_referral: {
        affiliate_code: profile.affiliate_code,
        visitor_id: "visitor-signup"
      }
    }, headers: auth_headers(referred_user)

    expect(response).to have_http_status(:created)
    referral = AffiliateSignupReferral.find_by!(referred_user: referred_user)
    expect(referral.affiliate_user).to eq(affiliate)
    expect(referral.visitor_id).to eq("visitor-signup")
  end

  it "does not replace an existing signup referral for the user" do
    existing = create(:affiliate_signup_referral, affiliate_user: affiliate, referred_user: referred_user)
    other_profile = create(:affiliate_profile, social_links: [ "https://instagram.com/signup-referrer-two" ])
    other_profile.approve!(admin)

    post "/api/v1/affiliate_signup_referrals", params: {
      affiliate_signup_referral: {
        affiliate_code: other_profile.affiliate_code,
        visitor_id: "visitor-signup"
      }
    }, headers: auth_headers(referred_user)

    expect(response).to have_http_status(:ok)
    expect(existing.reload.affiliate_user).to eq(affiliate)
    expect(AffiliateSignupReferral.count).to eq(1)
  end

  it "rejects self referrals" do
    post "/api/v1/affiliate_signup_referrals", params: {
      affiliate_signup_referral: {
        affiliate_code: profile.affiliate_code,
        visitor_id: "visitor-signup"
      }
    }, headers: auth_headers(affiliate)

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
