module Api
  module V1
    class AffiliatePayoutSettingsController < BaseController
      PROVIDERS = %w[mtn vodafone airteltigo].freeze
      COUNTRIES = %w[Ghana].freeze

      before_action :authenticate_user!
      before_action :ensure_approved_affiliate!

      def show
        render json: { data: payout_settings_json }, status: :ok
      end

      def update
        details = payout_params.to_h
        details["provider"] = details["provider"].to_s.strip.downcase
        details["phone_number"] = normalize_phone(details["phone_number"])
        details["country"] = "Ghana"

        errors = validate_payout_details(details)
        if errors.any?
          render json: { error: "Validation failed", errors: errors }, status: :unprocessable_entity
          return
        end

        current_user.affiliate_profile.update!(payout_details: details)

        render json: {
          data: payout_settings_json,
          message: "Payout settings updated successfully"
        }, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      private

      def ensure_approved_affiliate!
        return if current_user.affiliate_profile&.status == "approved" && current_user.active_affiliate?

        render json: { error: "Payout settings are available after approval" }, status: :forbidden
      end

      def payout_params
        params.require(:payout_details).permit(:provider, :account_name, :phone_number, :country)
      end

      def payout_settings_json
        {
          type: "affiliate_payout_settings",
          attributes: current_user.affiliate_profile.payout_details || {}
        }
      end

      def validate_payout_details(details)
        errors = []
        errors << "Provider is required" unless PROVIDERS.include?(details["provider"])
        errors << "Account name is required" if details["account_name"].to_s.strip.blank?
        errors << "Phone number must start with 233 and include 12 digits" unless details["phone_number"].match?(/\A233\d{9}\z/)
        errors << "Country must be Ghana" unless COUNTRIES.include?(details["country"])
        errors
      end

      def normalize_phone(value)
        digits = value.to_s.gsub(/\D/, "")
        digits = digits.sub(/\A0+/, "") unless digits.start_with?("233")
        digits = "233#{digits}" unless digits.start_with?("233")
        digits
      end
    end
  end
end
