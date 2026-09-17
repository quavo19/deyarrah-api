module Api
  module V1
    module Warehouses
      class ImagesController < BaseController
        before_action :authenticate_user!
        before_action :set_warehouse
        before_action :set_image, only: [ :destroy ]

        def index
          authorize @warehouse, :show?

          @images = policy_scope(Image).where(owner: @warehouse).order(created_at: :desc)

          render json: {
            data: @images.map do |image|
              {
                id: image.id,
                type: "image",
                attributes: {
                  owner_type: image.owner_type,
                  owner_id: image.owner_id,
                  url: image.url,
                  storage_key: image.storage_key,
                  created_at: image.created_at.iso8601,
                  updated_at: image.updated_at.iso8601
                }
              }
            end
          }, status: :ok
        end

        def create
          authorize @warehouse, :update?

          @image = Image.new(image_params)
          @image.owner = @warehouse

          if @image.save
            authorize @image
            render json: {
              data: {
                id: @image.id,
                type: "image",
                attributes: {
                  owner_type: @image.owner_type,
                  owner_id: @image.owner_id,
                  url: @image.url,
                  storage_key: @image.storage_key,
                  created_at: @image.created_at.iso8601,
                  updated_at: @image.updated_at.iso8601
                }
              }
            }, status: :created
          else
            render json: {
              error: "Validation failed",
              errors: @image.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        def destroy
          authorize @image

          if @image.destroy
            render json: {
              data: {
                id: @image.id,
                type: "image",
                attributes: {
                  owner_type: @image.owner_type,
                  owner_id: @image.owner_id,
                  url: @image.url,
                  storage_key: @image.storage_key,
                  created_at: @image.created_at.iso8601,
                  updated_at: @image.updated_at.iso8601
                }
              }
            }, status: :ok
          else
            render json: {
              error: "Failed to delete image",
              errors: @image.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        private

        def set_warehouse
          @warehouse = Warehouse.find(params[:warehouse_id])
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "Warehouse not found" }, status: :not_found
          nil
        end

        def set_image
          @image = Image.find_by(id: params[:id], owner: @warehouse)
          unless @image
            render json: { error: "Image not found" }, status: :not_found
            nil
          end
        end

        def image_params
          params.require(:image).permit(:url, :storage_key)
        end
      end
    end
  end
end
