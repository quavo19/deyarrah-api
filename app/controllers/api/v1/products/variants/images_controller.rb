module Api
  module V1
    module Products
      module Variants
        class ImagesController < BaseController
          before_action :authenticate_user!
          before_action :set_variant
          before_action :set_variant_option
          before_action :set_image, only: [ :destroy ]

          def index
            authorize @variant_option, :show?

            @images = policy_scope(Image).where(owner: @variant_option).order(created_at: :desc)

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
            authorize @variant_option, :update?

            @image = Image.new(image_params)
            @image.owner = @variant_option

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

          def set_variant
            @variant = VariantType.find(params[:variant_id] || params[:id])
          rescue ActiveRecord::RecordNotFound => e
            render json: { error: "Variant type not found" }, status: :not_found
            nil
          end

          def set_variant_option
            @variant_option = @variant.variant_options.find(params[:option_id])
          rescue ActiveRecord::RecordNotFound => e
            render json: { error: "Variant option not found" }, status: :not_found
            nil
          end

          def set_image
            @image = Image.find_by(id: params[:id], owner: @variant_option)
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
end
