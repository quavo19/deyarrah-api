module Api
  module V1
    module Products
      class VariantsController < BaseController
        before_action :authenticate_user!
        before_action :set_product, only: [ :index, :create ]
        before_action :set_variant, only: [ :show, :update, :destroy, :create_option, :index_options, :update_option, :destroy_option ]
        before_action :set_variant_option, only: [ :update_option, :destroy_option ]

        def index
          authorize VariantType
          @variants = policy_scope(VariantType).where(product_id: @product.id).order(created_at: :desc)

          render json: {
            data: @variants.map do |variant|
              {
                id: variant.id,
                type: "variant_type",
                attributes: {
                  product_id: variant.product_id,
                  name: variant.name,
                  description: variant.description,
                  pricing_role: variant.pricing_role,
                  created_at: variant.created_at.iso8601,
                  updated_at: variant.updated_at.iso8601
                }
              }
            end
          }, status: :ok
        end

        def show
          authorize @variant

          render json: {
            data: {
              id: @variant.id,
              type: "variant_type",
              attributes: {
                product_id: @variant.product_id,
                name: @variant.name,
                description: @variant.description,
                created_at: @variant.created_at.iso8601,
                updated_at: @variant.updated_at.iso8601
              }
            }
          }, status: :ok
        end

        def create
          authorize VariantType

          @variant = @product.variant_types.build(variant_params)

          if @variant.save
            # Delete all existing variant stocks for this product
            VariantStock.where(product_id: @product.id).destroy_all

            authorize @variant
            render json: {
              data: {
                id: @variant.id,
                type: "variant_type",
                attributes: {
                  product_id: @variant.product_id,
                  name: @variant.name,
                  description: @variant.description,
                  created_at: @variant.created_at.iso8601,
                  updated_at: @variant.updated_at.iso8601
                }
              }
            }, status: :created
          else
            render json: {
              error: @variant.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        def update
          authorize @variant

          if @variant.update(variant_params)
            render json: {
              data: {
                id: @variant.id,
                type: "variant_type",
                attributes: {
                  product_id: @variant.product_id,
                  name: @variant.name,
                  description: @variant.description,
                  created_at: @variant.created_at.iso8601,
                  updated_at: @variant.updated_at.iso8601
                }
              }
            }, status: :ok
          else
            render json: {
              error: @variant.errors.full_messages,
            }, status: :unprocessable_entity
          end
        end

        def destroy
          authorize @variant

          if @variant.destroy
            render json: {
              data: {
                id: @variant.id,
                type: "variant_type",
                attributes: {
                  product_id: @variant.product_id,
                  name: @variant.name,
                  description: @variant.description,
                  created_at: @variant.created_at.iso8601,
                  updated_at: @variant.updated_at.iso8601
                }
              }
            }, status: :ok
          else
            render json: {
              error: "Failed to delete variant type",
              errors: @variant.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        def index_options
          authorize VariantOption, :index?
          @variant_options = policy_scope(VariantOption).where(variant_type_id: @variant.id).includes(:images).order(created_at: :desc)

          render json: {
            data: @variant_options.map do |variant_option|
              {
                id: variant_option.id,
                type: "variant_option",
                attributes: {
                  variant_type_id: variant_option.variant_type_id,
                  name: variant_option.name,
                  description: variant_option.description,
                  price: variant_option.price.to_s,
                  images: format_variant_option_images(variant_option),
                  created_at: variant_option.created_at.iso8601,
                  updated_at: variant_option.updated_at.iso8601
                }
              }
            end
          }, status: :ok
        end

        def create_option
          authorize VariantOption, :create?

          @variant_option = @variant.variant_options.build(variant_option_params)

          if @variant_option.save
            authorize @variant_option, :create?
            @variant_option.reload
            @variant_option = VariantOption.includes(:images).find(@variant_option.id)
            
            render json: {
              data: {
                id: @variant_option.id,
                type: "variant_option",
                attributes: {
                  variant_type_id: @variant_option.variant_type_id,
                  name: @variant_option.name,
                  description: @variant_option.description,
                  price: @variant_option.price.to_s,
                  images: format_variant_option_images(@variant_option),
                  created_at: @variant_option.created_at.iso8601,
                  updated_at: @variant_option.updated_at.iso8601
                }
              }
            }, status: :created
          else
            render json: {
              error: @variant_option.errors.full_messages,
            }, status: :unprocessable_entity
          end
        end

        def update_option
          authorize @variant_option, :update?

          if @variant_option.update(variant_option_params)
            @variant_option.reload
            @variant_option = VariantOption.includes(:images).find(@variant_option.id)
            
            render json: {
              data: {
                id: @variant_option.id,
                type: "variant_option",
                attributes: {
                  variant_type_id: @variant_option.variant_type_id,
                  name: @variant_option.name,
                  description: @variant_option.description,
                  price: @variant_option.price.to_s,
                  images: format_variant_option_images(@variant_option),
                  created_at: @variant_option.created_at.iso8601,
                  updated_at: @variant_option.updated_at.iso8601
                }
              }
            }, status: :ok
          else
            render json: {
              error: @variant_option.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        def destroy_option
          authorize @variant_option, :destroy?

          option_id = @variant_option.id
          
          # Load images before destroying
          @variant_option = VariantOption.includes(:images).find(@variant_option.id)
          
          variant_option_data = {
            id: @variant_option.id,
            variant_type_id: @variant_option.variant_type_id,
            name: @variant_option.name,
            description: @variant_option.description,
            price: @variant_option.price.to_s,
            images: format_variant_option_images(@variant_option),
            created_at: @variant_option.created_at.iso8601,
            updated_at: @variant_option.updated_at.iso8601
          }

          VariantStock.where("? = ANY(option_ids)", option_id).destroy_all

          if @variant_option.destroy
            render json: {
              data: {
                id: variant_option_data[:id],
                type: "variant_option",
                attributes: variant_option_data.except(:id)
              }
            }, status: :ok
          else
            render json: {
              error: @variant_option.errors.full_messages
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

        def set_variant
          variant_id = params[:variant_id] || params[:id]
          @variant = VariantType.find(variant_id)
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

        def variant_params
          params.require(:variant_type).permit(:name, :description, :product_id, :pricing_role)
        end

        def variant_option_params
          params.require(:variant_option).permit(:name, :description, :price, :variant_type_id)
        end

        def format_variant_option_images(variant_option)
          variant_option.images.order(created_at: :desc).map do |image|
            {
              id: image.id,
              url: image.url,
              owner_type: "VariantOption",
              owner_id: variant_option.id,
              created_at: image.created_at.iso8601,
              updated_at: image.updated_at.iso8601
            }
          end
        end
      end
    end
  end
end
