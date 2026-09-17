module Api
  module V1
    class DeliveryHighValueRatesController < BaseController
      before_action :authenticate_admin!
      before_action :set_rate, only: [ :show, :update, :destroy ]

      def index
        rates = DeliveryHighValueRate.order(:pricing_zone, :shipping_category)
        render json: { data: rates.map { |rate| rate_json(rate) } }, status: :ok
      end

      def show
        render json: { data: rate_json(@rate) }, status: :ok
      end

      def create
        rate = DeliveryHighValueRate.new(rate_params)
        if rate.save
          render json: { data: rate_json(rate) }, status: :created
        else
          render json: { error: "Validation failed", errors: rate.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @rate.update(rate_params)
          render json: { data: rate_json(@rate) }, status: :ok
        else
          render json: { error: "Validation failed", errors: @rate.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @rate.destroy
        render json: { data: rate_json(@rate) }, status: :ok
      end

      private

      def set_rate
        @rate = DeliveryHighValueRate.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Delivery high-value rate not found" }, status: :not_found
      end

      def rate_params
        params.require(:delivery_high_value_rate).permit(:pricing_zone, :shipping_category, :fee)
      end

      def rate_json(rate)
        { id: rate.id, type: "delivery_high_value_rate", attributes: rate.attributes.except("id") }
      end
    end
  end
end
