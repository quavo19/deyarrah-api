module Api
  module V1
    class AffiliateDashboardController < BaseController
      before_action :authenticate_user!
      before_action :ensure_approved_affiliate!

      def show
        earnings = current_user.affiliate_earnings
        payable_earnings = earnings.where.not(status: "cancelled")
        page = [ params[:page].to_i, 1 ].max
        per_page = params[:per_page].to_i
        per_page = 10 unless per_page.positive?
        per_page = [ per_page, 50 ].min
        total_count = payable_earnings.count
        recent_earnings = payable_earnings
          .includes(:product, :order, :order_item)
          .order(earned_at: :desc, created_at: :desc)
          .offset((page - 1) * per_page)
          .limit(per_page)

        render json: {
          data: {
            type: "affiliate_dashboard",
            attributes: {
              summary: AffiliateBalanceService.summary_for(current_user),
              signup_referral_settings: signup_referral_settings_json,
              recent_earnings: recent_earnings.map { |earning| earning_json(earning) },
              recent_earnings_meta: {
                current_page: page,
                per_page: per_page,
                total_count: total_count,
                total_pages: (total_count.to_f / per_page).ceil
              }
            }
          }
        }, status: :ok
      end

      private

      def ensure_approved_affiliate!
        return if current_user.affiliate_profile&.status == "approved" && current_user.active_affiliate?

        render json: { error: "Affiliate dashboard is available after approval" }, status: :forbidden
      end

      def earning_json(earning)
        {
          id: earning.id,
          type: "affiliate_earning",
          attributes: {
            earning_type: earning.earning_type,
            order_id: earning.order&.order_id,
            product_id: earning.product_id,
            product_name: earning.product&.name,
            title: earning.earning_type == "signup_referral" ? "Signup referral reward" : earning.product&.name,
            quantity: earning.order_item&.quantity.to_i,
            sale_amount: earning.sale_amount.to_f,
            commission_amount: earning.commission_amount.to_f,
            currency: earning.currency,
            status: earning.status,
            earned_at: earning.earned_at&.iso8601,
            order_created_at: earning.order&.created_at&.iso8601
          }
        }
      end

      def signup_referral_settings_json
        settings = AffiliateSetting.current
        {
          percentage: settings.signup_referral_percentage.to_f,
          cap_amount: settings.signup_referral_cap_amount.to_f,
          enabled: settings.signup_referral_enabled,
          eligible_orders: 3
        }
      end
    end
  end
end
