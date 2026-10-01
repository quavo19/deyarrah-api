module Api
  module V1
    class DeliveryZonesController < BaseController
      before_action :authenticate_admin!
      before_action :set_zone, only: [ :show, :update, :destroy ]

      def index
        zones = DeliveryZone.order(:name)
        render json: { data: zones.map { |zone| zone_json(zone) } }, status: :ok
      end

      def show
        render json: { data: zone_json(@zone) }, status: :ok
      end

      def create
        zone = DeliveryZone.new(zone_params)
        if zone.save
          render json: { data: zone_json(zone) }, status: :created
        else
          render json: { error: "Validation failed", errors: zone.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @zone.update(zone_params)
          render json: { data: zone_json(@zone) }, status: :ok
        else
          render json: { error: "Validation failed", errors: @zone.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @zone.destroy
        render json: { data: zone_json(@zone) }, status: :ok
      end

      private

      def set_zone
        @zone = DeliveryZone.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Delivery zone not found" }, status: :not_found
      end

      def zone_params
        params.require(:delivery_zone).permit(
          :name,
          :code,
          :pricing_zone,
          :region,
          :city,
          :town,
          :market_name,
          :station_name,
          :region_open,
          :city_open,
          :town_open,
          :active
        )
      end

      def zone_json(zone)
        { id: zone.id, type: "delivery_zone", attributes: zone.attributes.except("id") }
      end
    end
  end
end
