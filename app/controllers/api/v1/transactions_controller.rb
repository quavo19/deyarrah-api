module Api
  module V1
    class TransactionsController < BaseController
      before_action :authenticate_admin!

      def index
        transactions = Transaction
          .includes(:user, :order, :affiliate_withdrawal)
          .order(created_at: :desc)

        transactions = transactions.where(status: params[:status]) if params[:status].present?
        transactions = transactions.where(purpose: params[:purpose]) if params[:purpose].present?

        if params[:search].present?
          term = "%#{params[:search].to_s.strip}%"
          transactions = transactions
            .left_joins(:user, :order)
            .where(
              "transactions.provider_reference ILIKE :term OR users.email ILIKE :term OR orders.order_id ILIKE :term",
              term: term
            )
        end

        page = [ params[:page].to_i, 1 ].max
        per_page = params[:per_page].to_i
        per_page = 25 unless per_page.positive?
        per_page = [ per_page, 100 ].min
        paginated = transactions.page(page).per(per_page)

        render json: {
          data: paginated.map { |transaction| transaction_json(transaction) },
          meta: {
            current_page: paginated.current_page,
            per_page: paginated.limit_value,
            total_pages: paginated.total_pages,
            total_count: paginated.total_count
          }
        }, status: :ok
      end

      private

      def transaction_json(transaction)
        {
          id: transaction.id,
          type: "transaction",
          attributes: {
            user_email: transaction.user&.email,
            user_name: [ transaction.user&.first_name, transaction.user&.last_name ].compact.join(" ").presence,
            order_id: transaction.order&.order_id,
            affiliate_withdrawal_id: transaction.affiliate_withdrawal_id,
            purpose: transaction.purpose,
            direction: transaction.direction,
            amount: transaction.amount_kobo.to_i / 100.0,
            amount_kobo: transaction.amount_kobo,
            currency: transaction.currency,
            status: transaction.status,
            provider: transaction.provider,
            provider_reference: transaction.provider_reference,
            metadata: transaction.metadata || {},
            processed_at: transaction.processed_at&.iso8601,
            created_at: transaction.created_at.iso8601,
            updated_at: transaction.updated_at.iso8601
          }
        }
      end
    end
  end
end
