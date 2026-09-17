module Api
  module V1
    class WarehousesController < BaseController
      before_action :authenticate_user!
      before_action :set_warehouse, only: [ :show, :update, :destroy ]

      def index
        authorize Warehouse
        @warehouses = policy_scope(Warehouse).includes(:images).order(:name)

        render json: {
          data: @warehouses.map do |warehouse|
            warehouse_json(warehouse)
          end
        }, status: :ok
      end

      def show
        authorize @warehouse

        render json: {
          data: warehouse_json(@warehouse)
        }, status: :ok
      end

      def create
        authorize Warehouse

        @warehouse = Warehouse.new(warehouse_params.except(:latitude, :longitude, :image_url, :image_storage_key))
        
        # Set location from latitude/longitude if provided
        if warehouse_params[:latitude].present? && warehouse_params[:longitude].present?
          @warehouse.set_location_from_coords(
            warehouse_params[:latitude].to_f,
            warehouse_params[:longitude].to_f
          )
        end

        if @warehouse.save
          # Create image if image_url is provided
          if warehouse_params[:image_url].present?
            @warehouse.images.create(url: warehouse_params[:image_url], storage_key: warehouse_params[:image_storage_key])
          end

          # Perform reverse geocoding synchronously after save
          if @warehouse.latitude.present? && @warehouse.longitude.present?
            begin
              ReverseGeocodingService.new(@warehouse).perform
              @warehouse.reload
            rescue => e
         
            end
          end
          
          authorize @warehouse
          render json: {
            data: warehouse_json(@warehouse)
          }, status: :created
        else
          render json: {
            error: "Validation failed",
            errors: @warehouse.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def update
        authorize @warehouse

        update_params = warehouse_params.except(:latitude, :longitude, :image_url, :image_storage_key)
        
        # Track if location is being updated
        location_changed = false
        if warehouse_params[:latitude].present? && warehouse_params[:longitude].present?
          @warehouse.set_location_from_coords(
            warehouse_params[:latitude].to_f,
            warehouse_params[:longitude].to_f
          )
          location_changed = true
        end

        if @warehouse.update(update_params)
          # Create image if image_url is provided
          if warehouse_params[:image_url].present?
            @warehouse.images.create(url: warehouse_params[:image_url], storage_key: warehouse_params[:image_storage_key])
          end

          # Perform reverse geocoding if location changed
          if location_changed && @warehouse.latitude.present? && @warehouse.longitude.present?
            ReverseGeocodingService.new(@warehouse).perform
            @warehouse.reload
          end
          
          render json: {
            data: warehouse_json(@warehouse)
          }, status: :ok
        else
          render json: {
            error: "Validation failed",
            errors: @warehouse.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @warehouse

        if @warehouse.destroy
          render json: {
            data: warehouse_json(@warehouse)
          }, status: :ok
        else
          render json: {
            error: "Failed to delete warehouse",
            errors: @warehouse.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def set_warehouse
        @warehouse = Warehouse.includes(:images).find(params[:id])
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: "Warehouse not found" }, status: :not_found
        nil
      end

      def warehouse_params
        params.require(:warehouse).permit(:name, :latitude, :longitude, :image_url, :image_storage_key, :delivery_rate_per_km)
      end

      def warehouse_json(warehouse)
        {
          id: warehouse.id,
          type: "warehouse",
          attributes: {
            name: warehouse.name,
            latitude: warehouse.latitude,
            longitude: warehouse.longitude,
            country: warehouse.country,
            region: warehouse.region,
            city: warehouse.city,
            county: warehouse.county,
            address: warehouse.address || {},
            delivery_rate_per_km: warehouse.delivery_rate_per_km.to_f,
            images: warehouse.images.sort_by(&:created_at).reverse.map do |image|
              {
                id: image.id,
                url: image.url,
                storage_key: image.storage_key,
                created_at: image.created_at.iso8601,
                updated_at: image.updated_at.iso8601
              }
            end,
            created_at: warehouse.created_at.iso8601,
            updated_at: warehouse.updated_at.iso8601
          }
        }
      end
    end
  end
end
