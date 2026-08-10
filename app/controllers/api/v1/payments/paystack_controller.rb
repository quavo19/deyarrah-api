module Api
  module V1
    module Payments
      class PaystackController < BaseController
        before_action :authenticate_user!, only: [ :initialize_payment, :verify ]

        def initialize_payment
          booking = current_user.bookings.find_by(id: params[:booking_id])

          unless booking
            render json: { error: "Booking not found" }, status: :not_found
            return
          end

          result = PaystackPaymentService.initialize_transaction(booking)

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

          booking = transaction.booking
          unless booking && booking.user_id == current_user.id
            render json: { error: "Not authorized to verify this transaction" }, status: :forbidden
            return
          end

          PaystackPaymentService.verify_transaction(reference)

          booking.reload
          transaction.reload

          render json: {
            booking_id: booking.id,
            booking_status: booking.status,
            payment_status: booking.payment_status,
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
      end
    end
  end
end
