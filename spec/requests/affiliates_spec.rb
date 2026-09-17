require "rails_helper"

RSpec.describe "Affiliates admin API", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:profile) { create(:affiliate_profile, user: user, status: "pending") }

  describe "GET /api/v1/affiliates" do
    it "requires admin access" do
      get "/api/v1/affiliates", headers: auth_headers(user)

      expect(response).to have_http_status(:forbidden)
    end

    it "lists affiliate applications for admins" do
      profile

      get "/api/v1/affiliates", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].size).to eq(1)
      expect(json_response.dig("data", 0, "id")).to eq(profile.id)
    end

    it "paginates affiliate applications" do
      create_list(:affiliate_profile, 3, status: "pending")

      get "/api/v1/affiliates", params: { page: 2, per_page: 2 }, headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].size).to eq(1)
      expect(json_response.dig("meta", "current_page")).to eq(2)
      expect(json_response.dig("meta", "per_page")).to eq(2)
      expect(json_response.dig("meta", "total_pages")).to eq(2)
      expect(json_response.dig("meta", "total_count")).to eq(3)
    end

    it "caps affiliate applications per page" do
      create_list(:affiliate_profile, 2, status: "pending")

      get "/api/v1/affiliates", params: { per_page: 500 }, headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response.dig("meta", "per_page")).to eq(100)
    end
  end

  describe "POST /api/v1/affiliates/:id/approve" do
    it "approves the profile and assigns the affiliate role" do
      post "/api/v1/affiliates/#{profile.id}/approve", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(profile.reload.status).to eq("approved")
      expect(profile.reviewed_by).to eq(admin)
      expect(user.reload.role.name).to eq("AFFILIATE")
    end
  end

  describe "POST /api/v1/affiliates/:id/reject" do
    it "rejects the profile with a reason" do
      post "/api/v1/affiliates/#{profile.id}/reject",
        params: { reason: "Audience is not a fit yet" },
        headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(profile.reload.status).to eq("rejected")
      expect(profile.rejection_reason).to eq("Audience is not a fit yet")
    end
  end

  describe "POST /api/v1/affiliates/:id/suspend" do
    let(:profile) { create(:affiliate_profile, user: user, status: "approved") }

    it "suspends the profile, removes affiliate access, and cancels unpaid affiliate records" do
      profile.approve!(admin)
      earning = create(:affiliate_earning, affiliate_user: user, status: "available")
      withdrawal = create(:affiliate_withdrawal, affiliate_user: user, status: "pending")
      attribution = create(:affiliate_attribution, affiliate_user: user, expires_at: 20.days.from_now)

      post "/api/v1/affiliates/#{profile.id}/suspend",
        params: { reason: "Policy violation" },
        headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(profile.reload.status).to eq("suspended")
      expect(profile.suspended_at).to be_present
      expect(profile.rejection_reason).to eq("Policy violation")
      expect(user.reload.role.name).to eq("CUSTOMER")
      expect(earning.reload.status).to eq("cancelled")
      expect(withdrawal.reload.status).to eq("cancelled")
      expect(withdrawal.reviewed_by).to eq(admin)
      expect(attribution.reload.expires_at).to be <= Time.current
    end
  end

  describe "POST /api/v1/affiliates/:id/reactivate" do
    let(:profile) { create(:affiliate_profile, user: user, status: "suspended", suspended_at: 1.day.ago) }

    it "reactivates the profile and restores the affiliate role" do
      post "/api/v1/affiliates/#{profile.id}/reactivate", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(profile.reload.status).to eq("approved")
      expect(profile.suspended_at).to be_nil
      expect(user.reload.role.name).to eq("AFFILIATE")
    end
  end
end
