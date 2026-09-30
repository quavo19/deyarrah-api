module Api
  module V1
    class AffiliateWithdrawalsController < BaseController
      MINIMUM_WITHDRAWAL_AMOUNT = BigDecimal("1.0")

      before_action :authenticate_user!
      before_action :ensure_approved_affiliate!

      def index
        withdrawals = current_user.affiliate_withdrawals.order(requested_at: :desc, created_at: :desc)

        render json: {
          data: withdrawals.map { |withdrawal| withdrawal_json(withdrawal) },
          meta: {
            summary: AffiliateBalanceService.summary_for(current_user)
          }
        }, status: :ok
      end

      def create
        amount = withdrawal_params[:amount].to_d
        available_balance = AffiliateBalanceService.summary_for(current_user)[:available_balance].to_d

        errors = []
        errors << "Complete payout settings before requesting a withdrawal" unless payout_details_complete?
        errors << "Withdrawal amount must be greater than GHS 1.00" unless amount > MINIMUM_WITHDRAWAL_AMOUNT
        errors << "Withdrawal amount exceeds available balance" if amount > available_balance

        if errors.any?
          render json: { error: errors.first, errors: errors }, status: :unprocessable_entity
          return
        end

        withdrawal = current_user.affiliate_withdrawals.create!(
          amount: amount,
          currency: "GHS",
          status: "pending",
          payout_details: current_user.affiliate_profile.payout_details
        )

        render json: {
          data: withdrawal_json(withdrawal),
          meta: {
            summary: AffiliateBalanceService.summary_for(current_user)
          },
          message: "Withdrawal request submitted successfully"
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      private

      def ensure_approved_affiliate!
        return if current_user.affiliate_profile&.status == "approved" && current_user.active_affiliate?

        render json: { error: "Withdrawals are available after approval" }, status: :forbidden
      end

      def withdrawal_params
        params.require(:affiliate_withdrawal).permit(:amount)
      end

      def payout_details_complete?
        details = current_user.affiliate_profile.payout_details || {}
        details["provider"].present? &&
          details["account_name"].present? &&
          details["phone_number"].to_s.match?(/\A233\d{9}\z/) &&
          details["country"] == "Ghana"
      end

      def withdrawal_json(withdrawal)
        {
          id: withdrawal.id,
          type: "affiliate_withdrawal",
          attributes: {
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
