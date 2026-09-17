require "rails_helper"

RSpec.describe "Support requests admin API", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  describe "GET /api/v1/support_requests" do
    it "requires admin access" do
      get "/api/v1/support_requests", headers: auth_headers(user)

      expect(response).to have_http_status(:forbidden)
    end

    it "paginates support requests" do
      create_list(:support_request, 3)

      get "/api/v1/support_requests", params: { page: 2, per_page: 2 }, headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].size).to eq(1)
      expect(json_response.dig("meta", "current_page")).to eq(2)
      expect(json_response.dig("meta", "per_page")).to eq(2)
      expect(json_response.dig("meta", "total_pages")).to eq(2)
      expect(json_response.dig("meta", "total_count")).to eq(3)
    end

    it "caps support requests per page" do
      create_list(:support_request, 2)

      get "/api/v1/support_requests", params: { per_page: 500 }, headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response.dig("meta", "per_page")).to eq(100)
    end
  end
end
