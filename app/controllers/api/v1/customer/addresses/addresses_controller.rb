module Api
  module V1
    module Customer
      module Addresses
        class AddressesController < BaseController
          before_action :authenticate_user!
          before_action :set_address, only: [ :show, :update, :destroy, :set_default ]

          def index
            @addresses = current_user.customer_addresses.order(created_at: :desc)

            render json: {
              data: @addresses.map do |address|
                {
                  id: address.id,
                  type: "customer_address",
                  attributes: {
                    name: address.name,
                    latitude: address.latitude&.to_f,
                    longitude: address.longitude&.to_f,
                    country: address.country,
                    region: address.region,
                    city: address.city,
                    county: address.county,
                    address: address.address,
                    is_default: address.is_default,
                    created_at: address.created_at.iso8601,
                    updated_at: address.updated_at.iso8601
                  }
                }
              end
            }, status: :ok
          end

          def show
            render json: {
              data: {
                id: @address.id,
                type: "customer_address",
                attributes: {
                  name: @address.name,
                  latitude: @address.latitude.to_f,
                  longitude: @address.longitude.to_f,
                  country: @address.country,
                  region: @address.region,
                  city: @address.city,
                  county: @address.county,
                  address: @address.address,
                  is_default: @address.is_default,
                  created_at: @address.created_at.iso8601,
                  updated_at: @address.updated_at.iso8601
                }
              }
            }, status: :ok
          end

          def create
            if current_user.customer_addresses.count >= 3
              render json: {
                error: "Address limit reached",
                errors: [ "You can save up to 3 addresses" ]
              }, status: :unprocessable_entity
              return
            end

            @address = current_user.customer_addresses.build(address_params)

            if @address.save
              # Trigger reverse geocoding in background if coordinates are provided
              if @address.latitude.present? && @address.longitude.present?
                ReverseGeocodingService.new(@address).perform
              end

              render json: {
                data: {
                  id: @address.id,
                  type: "customer_address",
                  attributes: {
                    name: @address.name,
                    latitude: @address.latitude&.to_f,
                    longitude: @address.longitude&.to_f,
                    country: @address.country,
                    region: @address.region,
                    city: @address.city,
                    county: @address.county,
                    address: @address.address,
                    is_default: @address.is_default,
                    created_at: @address.created_at.iso8601,
                    updated_at: @address.updated_at.iso8601
                  }
                }
              }, status: :created
            else
              render json: {
                error: "Validation failed",
                errors: @address.errors.full_messages
              }, status: :unprocessable_entity
            end
          end

          def update
            if @address.update(address_params)
              # Trigger reverse geocoding if coordinates changed
              if @address.latitude.present? && @address.longitude.present?
                ReverseGeocodingService.new(@address).perform
              end

              render json: {
                data: {
                  id: @address.id,
                  type: "customer_address",
                  attributes: {
                    name: @address.name,
                    latitude: @address.latitude&.to_f,
                    longitude: @address.longitude&.to_f,
                    country: @address.country,
                    region: @address.region,
                    city: @address.city,
                    county: @address.county,
                    address: @address.address,
                    is_default: @address.is_default,
                    created_at: @address.created_at.iso8601,
                    updated_at: @address.updated_at.iso8601
                  }
                }
              }, status: :ok
            else
              render json: {
                error: "Validation failed",
                errors: @address.errors.full_messages
              }, status: :unprocessable_entity
            end
          end

          def destroy
            if @address.destroy
              render json: { message: "Address deleted successfully" }, status: :ok
            else
              render json: {
                error: "Failed to delete address",
                errors: @address.errors.full_messages
              }, status: :unprocessable_entity
            end
          end

          def set_default
            @address.set_as_default!
            render json: {
              data: {
                id: @address.id,
                type: "customer_address",
                attributes: {
                  name: @address.name,
                    latitude: @address.latitude&.to_f,
                    longitude: @address.longitude&.to_f,
                  country: @address.country,
                  region: @address.region,
                  city: @address.city,
                  county: @address.county,
                  address: @address.address,
                  is_default: @address.is_default,
                  created_at: @address.created_at.iso8601,
                  updated_at: @address.updated_at.iso8601
                }
              }
            }, status: :ok
          end

          private

          def set_address
            @address = current_user.customer_addresses.find_by(id: params[:id])
            unless @address
              render json: { error: "Address not found" }, status: :not_found
            end
          end

          def address_params
            params.require(:address).permit(:name, :latitude, :longitude, :country, :region, :city, :county, :is_default, address: {})
          end
        end
      end
    end
  end
end
