module Api
  module V1
    class AffiliateSettingsController < BaseController
      before_action :authenticate_admin!, only: [ :update ]

      def show
        render json: { data: settings_json(AffiliateSetting.current) }, status: :ok
      end

      def update
        settings = AffiliateSetting.current
        if settings.update(settings_params)
          render json: {
            data: settings_json(settings),
            message: "Affiliate settings updated successfully"
          }, status: :ok
        else
          render json: { error: settings.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      private

      def settings_params
        params.require(:affiliate_settings).permit(
          :signup_referral_percentage,
          :signup_referral_cap_amount,
          :signup_referral_enabled
        )
      end

      def settings_json(settings)
        {
          type: "affiliate_settings",
          attributes: {
            signup_referral_percentage: settings.signup_referral_percentage.to_f,
            signup_referral_cap_amount: settings.signup_referral_cap_amount.to_f,
            signup_referral_enabled: settings.signup_referral_enabled
          }
        }
      end
    end
  end
end
