module Api
  module V1
    module Customer
      class DeliveryZonesController < BaseController
        def index
          zones = DeliveryZone.active.order(:region, :city, :town, :market_name, :name)

          render json: {
            data: zones.map { |zone| zone_json(zone) }
          }, status: :ok
        end

        private

        def zone_json(zone)
          {
            id: zone.id,
            type: "delivery_zone",
            attributes: zone.attributes.except("id")
          }
        end
      end
    end
  end
end
