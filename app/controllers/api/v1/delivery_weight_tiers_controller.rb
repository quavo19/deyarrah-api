module Api
  module V1
    class DeliveryWeightTiersController < BaseController
      before_action :authenticate_admin!
      before_action :set_tier, only: [ :show, :update, :destroy ]

      def index
        tiers = DeliveryWeightTier.order(:pricing_zone, :min_weight_kg)
        render json: { data: tiers.map { |tier| tier_json(tier) } }, status: :ok
      end

      def show
        render json: { data: tier_json(@tier) }, status: :ok
      end

      def create
        tier = DeliveryWeightTier.new(tier_params)
        if tier.save
          render json: { data: tier_json(tier) }, status: :created
        else
          render json: { error: "Validation failed", errors: tier.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @tier.update(tier_params)
          render json: { data: tier_json(@tier) }, status: :ok
        else
          render json: { error: "Validation failed", errors: @tier.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @tier.destroy
        render json: { data: tier_json(@tier) }, status: :ok
      end

      private

      def set_tier
        @tier = DeliveryWeightTier.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Delivery weight tier not found" }, status: :not_found
      end

      def tier_params
        params.require(:delivery_weight_tier).permit(:pricing_zone, :min_weight_kg, :max_weight_kg, :fee)
      end

      def tier_json(tier)
        { id: tier.id, type: "delivery_weight_tier", attributes: tier.attributes.except("id") }
      end
    end
  end
end
