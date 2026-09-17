module Api
  module V1
    module Products
      class ImagesController < BaseController
        before_action :authenticate_user!
        before_action :set_owner_for_index, only: [ :index ]
        before_action :set_owner_for_create, only: [ :create ]
        before_action :set_image, only: [ :update, :destroy ]

        def index
          return unless @owner

          authorize @owner, :show?

          @images = policy_scope(Image).where(owner: @owner).order(created_at: :desc)

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
          return unless @owner

          authorize @owner, :update?

          @image = Image.new(image_params.except(:owner_type, :owner_id))
          @image.owner = @owner

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

        def update
          authorize @image

          if @image.update(image_params.except(:owner_type, :owner_id))
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

        def set_owner_for_index
          owner_type = params[:owner_type]
          owner_id = params[:owner_id]

          unless owner_type.present? && owner_id.present?
            render json: { error: "owner_type and owner_id query parameters are required" }, status: :unprocessable_entity
            return
          end

          @owner = find_owner(owner_type, owner_id)
        end

        def set_owner_for_create
          owner_type = params[:image]&.dig(:owner_type)
          owner_id = params[:image]&.dig(:owner_id)

          unless owner_type.present? && owner_id.present?
            render json: { error: "owner_type and owner_id are required in request body" }, status: :unprocessable_entity
            return
          end

          @owner = find_owner(owner_type, owner_id)
        end

        def find_owner(owner_type, owner_id)
          unless ["Product", "VariantOption", "Warehouse"].include?(owner_type)
            render json: { error: "owner_type must be Product, VariantOption, or Warehouse" }, status: :unprocessable_entity
            return nil
          end

          owner_type.constantize.find(owner_id)
        rescue NameError => e
          render json: { error: "Invalid owner_type" }, status: :unprocessable_entity
          nil
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "#{owner_type} not found" }, status: :not_found
          nil
        end

        def set_image
          @image = Image.find(params[:id])
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "Image not found" }, status: :not_found
          nil
        end

        def image_params
          params.require(:image).permit(:owner_type, :owner_id, :url, :storage_key)
        end
      end
    end
  end
end
