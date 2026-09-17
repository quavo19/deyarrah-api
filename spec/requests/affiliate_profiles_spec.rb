require "rails_helper"

RSpec.describe "Affiliate profiles", type: :request do
  let(:user) { create(:user) }

  let(:valid_payload) do
    {
      affiliate_profile: {
        full_name: "Ama Mensah",
        email: user.email,
        phone: "+233555000000",
        country: "Ghana",
        city: "Accra",
        social_links: [ "https://instagram.com/ama" ],
        promotion_channels: [ "Instagram", "TikTok" ],
        audience_size: 2500,
        content_niche: "Plants and lifestyle",
        reason: "I create plant care content and want to promote the shop.",
        payout_details: {
          provider: "mobile_money",
          account_name: "Ama Mensah",
          account_number: "+233555000000"
        },
        terms_accepted: true
      }
    }
  end

  describe "GET /api/v1/affiliate_profile" do
    it "returns not_applied for a user without an application" do
      get "/api/v1/affiliate_profile", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]).to be_nil
      expect(json_response["application_status"]).to eq("not_applied")
    end
  end

  describe "POST /api/v1/affiliate_profile" do
    it "creates a pending affiliate application for the current user" do
      post "/api/v1/affiliate_profile", params: valid_payload, headers: auth_headers(user)

      expect(response).to have_http_status(:created)
      expect(json_response.dig("data", "attributes", "status")).to eq("pending")
      expect(user.reload.affiliate_profile).to be_present
      expect(user.role.name).to eq("CUSTOMER")
    end

    it "rejects missing required fields" do
      invalid_payload = valid_payload.deep_dup
      invalid_payload[:affiliate_profile][:phone] = ""

      post "/api/v1/affiliate_profile", params: invalid_payload, headers: auth_headers(user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to include("Phone can't be blank")
    end

    it "prevents duplicate active applications" do
      create(:affiliate_profile, user: user, status: "pending")

      post "/api/v1/affiliate_profile", params: valid_payload, headers: auth_headers(user)

      expect(response).to have_http_status(:conflict)
      expect(json_response["error"]).to eq("Your affiliate application is already under review.")
    end

    it "prevents rejected applications from being submitted again before 2 weeks" do
      profile = create(:affiliate_profile, user: user, status: "rejected", rejection_reason: "Too small", reviewed_at: 13.days.ago)

      post "/api/v1/affiliate_profile", params: valid_payload, headers: auth_headers(user)

      expect(response).to have_http_status(:forbidden)
      expect(json_response["error"]).to eq("You can submit another affiliate application 2 weeks after the last denial.")
      expect(profile.reload.status).to eq("rejected")
    end

    it "allows a rejected application to be submitted again after 2 weeks" do
      profile = create(:affiliate_profile, user: user, status: "rejected", rejection_reason: "Too small", reviewed_at: 15.days.ago)

      post "/api/v1/affiliate_profile", params: valid_payload, headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(profile.reload.status).to eq("pending")
      expect(profile.rejection_reason).to be_nil
    end
  end
end
