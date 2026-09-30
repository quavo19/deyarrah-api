module Api
  module V1
    class AffiliateSignupReferralsController < BaseController
      before_action :authenticate_user!

      def create
        profile = AffiliateProfile.includes(:user).find_by(
          affiliate_code: signup_referral_params[:affiliate_code].to_s.strip.upcase,
          status: "approved"
        )

        unless profile&.user&.active_affiliate?
          render json: { error: "Affiliate referral link is not active" }, status: :unprocessable_entity
          return
        end

        if profile.user_id == current_user.id
          render json: { error: "Self referrals are not allowed" }, status: :unprocessable_entity
          return
        end

        referral = AffiliateSignupReferral.find_or_initialize_by(referred_user: current_user)
        if referral.persisted?
          render json: { data: referral_json(referral), message: "Signup referral already tracked" }, status: :ok
          return
        end

        referral.assign_attributes(
          affiliate_user: profile.user,
          visitor_id: signup_referral_params[:visitor_id].presence,
          referred_at: Time.current
        )
        referral.save!

        render json: {
          data: referral_json(referral),
          message: "Signup referral tracked"
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      private

      def signup_referral_params
        params.require(:affiliate_signup_referral).permit(:affiliate_code, :visitor_id)
      end

      def referral_json(referral)
        {
          id: referral.id,
          type: "affiliate_signup_referral",
          attributes: {
            affiliate_code: referral.affiliate_user.affiliate_profile&.affiliate_code,
            rewarded_orders_count: referral.rewarded_orders_count,
            referred_at: referral.referred_at&.iso8601,
            converted_at: referral.converted_at&.iso8601
          }
        }
      end
    end
  end
end
