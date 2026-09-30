module Api
  module V1
    class AdminAffiliateWithdrawalsController < BaseController
      before_action :authenticate_admin!
      before_action :set_withdrawal, only: [ :approve, :reject, :pay ]

      def index
        withdrawals = AffiliateWithdrawal.includes(affiliate_user: :affiliate_profile).order(requested_at: :desc, created_at: :desc)
        withdrawals = withdrawals.where(status: params[:status]) if params[:status].present?

        render json: {
          data: withdrawals.map { |withdrawal| withdrawal_json(withdrawal) }
        }, status: :ok
      end

      def approve
        unless current_user.has_role?("SUPER_ADMIN")
          render json: { error: "Only super admins can approve affiliate withdrawals" }, status: :forbidden
          return
        end

        unless approved_active_affiliate?(@withdrawal.affiliate_user)
          render json: { error: "Cannot approve withdrawal for a blocked or suspended affiliate" }, status: :forbidden
          return
        end

        @withdrawal.update!(status: "approved", reviewed_by: current_user, reviewed_at: Time.current)

        render json: {
          data: withdrawal_json(@withdrawal),
          message: "Withdrawal approved"
        }, status: :ok
      end

      def reject
        @withdrawal.update!(
          status: "rejected",
          reviewed_by: current_user,
          reviewed_at: Time.current,
          admin_note: params[:reason].to_s.strip.presence
        )

        render json: {
          data: withdrawal_json(@withdrawal),
          message: "Withdrawal rejected"
        }, status: :ok
      end

      def pay
        unless approved_active_affiliate?(@withdrawal.affiliate_user)
          render json: { error: "Cannot pay withdrawal for a blocked or suspended affiliate" }, status: :forbidden
          return
        end

        PaystackTransferService.initiate_withdrawal!(@withdrawal)
        @withdrawal.reload

        render json: {
          data: withdrawal_json(@withdrawal),
          message: "Paystack transfer initiated"
        }, status: :ok
      rescue PaystackTransferService::PaystackTransferError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def set_withdrawal
        @withdrawal = AffiliateWithdrawal.find_by(id: params[:id])
        return if @withdrawal

        render json: { error: "Withdrawal not found" }, status: :not_found
      end

      def approved_active_affiliate?(user)
        user.active_affiliate? && user.affiliate_profile&.status == "approved"
      end

      def withdrawal_json(withdrawal)
        profile = withdrawal.affiliate_user.affiliate_profile
        {
          id: withdrawal.id,
          type: "affiliate_withdrawal",
          attributes: {
            affiliate_name: profile&.full_name,
            affiliate_email: profile&.email || withdrawal.affiliate_user.email,
            affiliate_code: profile&.affiliate_code,
            amount: withdrawal.amount.to_f,
            currency: withdrawal.currency,
            status: withdrawal.status,
            payout_details: withdrawal.payout_details || {},
            requested_at: withdrawal.requested_at&.iso8601,
            reviewed_at: withdrawal.reviewed_at&.iso8601,
            paid_at: withdrawal.paid_at&.iso8601,
            admin_note: withdrawal.admin_note
          }
        }
      end
    end
  end
end
