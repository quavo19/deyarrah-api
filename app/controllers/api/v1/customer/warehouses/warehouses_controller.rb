module Api
  module V1
    module Customer
      module Warehouses
        class WarehousesController < BaseController
          before_action :authenticate_user!

          def index
            @warehouses = Warehouse.all.order(:name)

            render json: {
              data: @warehouses.map do |warehouse|
                {
                  id: warehouse.id,
                  type: "warehouse",
                  attributes: {
                    name: warehouse.name,
                    latitude: warehouse.latitude.to_f,
                    longitude: warehouse.longitude.to_f,
                    address: warehouse.address || {},
                    country: warehouse.country,
                    region: warehouse.region,
                    city: warehouse.city,
                    county: warehouse.county
                  }
                }
              end
            }, status: :ok
          end
        end
      end
    end
  end
end
