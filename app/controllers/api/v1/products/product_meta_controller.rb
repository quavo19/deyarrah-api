module Api
  module V1
    module Products
      class ProductMetaController < BaseController
        before_action :authenticate_user!
        before_action :set_product
        before_action :set_product_meta, only: [ :update, :destroy ]

        def index
          authorize ProductMeta
          @product_meta = policy_scope(ProductMeta).where(product_id: @product.id).order(created_at: :desc)

          render json: {
            data: @product_meta.map do |meta|
              {
                id: meta.id,
                type: "product_meta",
                attributes: {
                  product_id: meta.product_id,
                  name: meta.name,
                  value: meta.value,
                  created_at: meta.created_at.iso8601,
                  updated_at: meta.updated_at.iso8601
                }
              }
            end
          }, status: :ok
        end

        def create
          authorize ProductMeta

          @product_meta = @product.product_meta.build(product_meta_params)

          if @product_meta.save
            authorize @product_meta
            render json: {
              data: {
                id: @product_meta.id,
                type: "product_meta",
                attributes: {
                  product_id: @product_meta.product_id,
                  name: @product_meta.name,
                  value: @product_meta.value,
                  created_at: @product_meta.created_at.iso8601,
                  updated_at: @product_meta.updated_at.iso8601
                }
              }
            }, status: :created
          else
            render json: {
              error: "Validation failed",
              errors: @product_meta.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        def update
          authorize @product_meta

          if @product_meta.update(product_meta_params)
            render json: {
              data: {
                id: @product_meta.id,
                type: "product_meta",
                attributes: {
                  product_id: @product_meta.product_id,
                  name: @product_meta.name,
                  value: @product_meta.value,
                  created_at: @product_meta.created_at.iso8601,
                  updated_at: @product_meta.updated_at.iso8601
                }
              }
            }, status: :ok
          else
            render json: {
              error: "Validation failed",
              errors: @product_meta.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        def destroy
          authorize @product_meta

          if @product_meta.destroy
            render json: {
              data: {
                id: @product_meta.id,
                type: "product_meta",
                attributes: {
                  product_id: @product_meta.product_id,
                  name: @product_meta.name,
                  value: @product_meta.value,
                  created_at: @product_meta.created_at.iso8601,
                  updated_at: @product_meta.updated_at.iso8601
                }
              }
            }, status: :ok
          else
            render json: {
              error: "Failed to delete product meta",
              errors: @product_meta.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        private

        def set_product
          @product = Product.find(params[:product_id])
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "Product not found" }, status: :not_found
          nil
        end

        def set_product_meta
          @product_meta = @product.product_meta.find(params[:id])
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "Product meta not found" }, status: :not_found
          nil
        end

        def product_meta_params
          params.require(:product_meta).permit(:name, :value)
        end
      end
    end
  end
end
