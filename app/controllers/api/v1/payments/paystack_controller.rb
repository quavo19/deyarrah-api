module Api
  module V1
    module Payments
      class PaystackController < BaseController
        before_action :authenticate_user!, only: [ :initialize_payment, :verify ]

        def initialize_payment
          order = find_current_user_order(params[:order_id])

          unless order
            render json: { error: "Order not found" }, status: :not_found
            return
          end

          result = PaystackPaymentService.initialize_transaction(order, callback_url: params[:callback_url])

          render json: {
            authorization_url: result[:authorization_url],
            reference: result[:reference],
            transaction_id: result[:transaction].id
          }, status: :ok
        rescue PaystackPaymentService::PaystackError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        # Frontend-friendly verification endpoint (useful in local dev where webhooks may not reach your API).
        # Call this after Paystack redirects back to your frontend, using the `reference` you received from initialize.
        def verify
          reference = params[:reference]
          if reference.blank?
            render json: { error: "reference is required" }, status: :unprocessable_entity
            return
          end

          transaction = Transaction.find_by(provider_reference: reference)
          unless transaction
            render json: { error: "Transaction not found" }, status: :not_found
            return
          end

          order = transaction.order
          unless order && order.user_id == current_user.id
            render json: { error: "Not authorized to verify this transaction" }, status: :forbidden
            return
          end

          PaystackPaymentService.verify_transaction(reference)

          order.reload
          transaction.reload

          render json: {
            id: order.id,
            order_id: order.order_id,
            order_status: order.status,
            payment_status: order.payment_status,
            transaction_status: transaction.status,
            reference: reference
          }, status: :ok
        rescue PaystackPaymentService::PaystackError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        # Paystack webhook URL
        # Configure this URL in your Paystack dashboard
        def webhook
          payload = params.to_unsafe_h

          PaystackPaymentService.handle_webhook(payload)

          head :ok
        rescue PaystackPaymentService::PaystackError => e
          Rails.logger.error("Paystack webhook error: #{e.message}")
          head :unprocessable_entity
        end

        private

        def find_current_user_order(identifier)
          current_user.orders
            .where("orders.id::text = :id OR orders.order_id = :order_id", id: identifier, order_id: identifier.to_s.upcase)
            .first
        end
      end
    end
  end
end
