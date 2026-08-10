module Api
  module V1
    module Products
      class ProductsController < BaseController
        before_action :authenticate_user!
        before_action :set_product, only: [ :show, :update, :destroy ]

        def index
          authorize Product
          @products = policy_scope(Product).includes(
            :category,
            :images,
            variant_types: { variant_options: :images }
          ).order(created_at: :desc)

          if params[:search].present?
            search_term = "%#{params[:search]}%"
            @products = @products.where(
              "name ILIKE ? OR description ILIKE ?",
              search_term, search_term
            )
          end

          @products = @products.where(category_id: params[:category_id]) if params[:category_id].present?

          if params[:active].present?
            active_value = ActiveModel::Type::Boolean.new.cast(params[:active])
            @products = @products.where(active: active_value)
          end
          @products = @products.where(bookable_type: params[:bookable_type]) if params[:bookable_type].present?

          page = params[:page] || 1
          per_page = params[:per_page] || 25
          @products = @products.page(page).per(per_page)

          render json: {
            data: @products.map do |product|
              {
                id: product.id,
                type: "product",
                attributes: {
                  name: product.name,
                  description: product.description,
                  bookable_type: product.bookable_type,
                  active: product.active,
                  status: product.status,
                  category_id: product.category_id,
                  delivery_rate_per_km: product.delivery_rate_per_km.to_f,
                  category: product.category ? {
                    id: product.category.id,
                    name: product.category.name
                  } : nil,
                  total_stock: calculate_total_stock(product),
                  images: format_product_images(product),
                  created_at: product.created_at.iso8601,
                  updated_at: product.updated_at.iso8601
                }
              }
            end,
            meta: {
              current_page: @products.current_page,
              per_page: @products.limit_value,
              total_pages: @products.total_pages,
              total_count: @products.total_count
            }
          }, status: :ok
        end

        def show
          authorize @product
          @product = Product.includes(
            :category,
            :images,
            variant_types: { variant_options: :images }
          ).find(@product.id)

          render json: {
            data: {
              id: @product.id,
              type: "product",
              attributes: {
                name: @product.name,
                description: @product.description,
                bookable_type: @product.bookable_type,
                active: @product.active,
                status: @product.status,
                category_id: @product.category_id,
                delivery_rate_per_km: @product.delivery_rate_per_km.to_f,
                category: @product.category ? {
                  id: @product.category.id,
                  name: @product.category.name
                } : nil,
                images: format_product_images(@product),
                created_at: @product.created_at.iso8601,
                updated_at: @product.updated_at.iso8601
              }
            }
          }, status: :ok
        end

        def create
          authorize Product

          @product = Product.new(product_params)

          if @product.save
            authorize @product
            @product.reload
            @product = Product.includes(
              :category,
              :images,
              variant_types: { variant_options: :images }
            ).find(@product.id)

            render json: {
              data: {
                id: @product.id,
                type: "product",
                  attributes: {
                  name: @product.name,
                  description: @product.description,
                  bookable_type: @product.bookable_type,
                  active: @product.active,
                  category_id: @product.category_id,
                  delivery_rate_per_km: @product.delivery_rate_per_km.to_f,
                  category: @product.category ? {
                    id: @product.category.id,
                    name: @product.category.name
                  } : nil,
                  images: format_product_images(@product),
                  created_at: @product.created_at.iso8601,
                  updated_at: @product.updated_at.iso8601
                }
              }
            }, status: :created
          else
            render json: {
              error: "Validation failed",
              errors: @product.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        def update
          authorize @product

          if @product.update(product_params)
            @product.reload
            @product = Product.includes(
              :category,
              :images,
              variant_types: { variant_options: :images }
            ).find(@product.id)

            render json: {
              data: {
                id: @product.id,
                type: "product",
                  attributes: {
                  name: @product.name,
                  description: @product.description,
                  bookable_type: @product.bookable_type,
                  active: @product.active,
                  category_id: @product.category_id,
                  delivery_rate_per_km: @product.delivery_rate_per_km.to_f,
                  category: @product.category ? {
                    id: @product.category.id,
                    name: @product.category.name
                  } : nil,
                  images: format_product_images(@product),
                  created_at: @product.created_at.iso8601,
                  updated_at: @product.updated_at.iso8601
                }
              }
            }, status: :ok
          else
            render json: {
              error: "Validation failed",
              errors: @product.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        def destroy
          authorize @product

          # Load images before destroying
          @product = Product.includes(
            :category,
            :images,
            variant_types: { variant_options: :images }
          ).find(@product.id)

          product_data = {
            id: @product.id,
            name: @product.name,
            description: @product.description,
            bookable_type: @product.bookable_type,
            active: @product.active,
            category_id: @product.category_id,
            category: @product.category ? {
              id: @product.category.id,
              name: @product.category.name
            } : nil,
            images: format_product_images(@product),
            created_at: @product.created_at.iso8601,
            updated_at: @product.updated_at.iso8601
          }

          if @product.destroy
            render json: {
              data: {
                id: product_data[:id],
                type: "product",
                attributes: product_data.except(:id)
              }
            }, status: :ok
          else
            render json: {
              error: "Failed to delete product",
              errors: @product.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        private

        def set_product
          @product = Product.find(params[:id])
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "Product not found" }, status: :not_found
          nil
        end

        def product_params
          params.require(:product).permit(:name, :description, :bookable_type, :active, :category_id, :delivery_rate_per_km)
        end

        def calculate_total_stock(product)
          # Sum all variant stocks for this product - works for both bulk and unit products
          VariantStock.where(product_id: product.id).sum(:quantity)
        end

        def format_product_images(product)
          # Get product images
          product_images = product.images.order(created_at: :desc).map do |image|
            {
              id: image.id,
              url: image.url,
              owner_type: "Product",
              owner_id: product.id,
              created_at: image.created_at.iso8601,
              updated_at: image.updated_at.iso8601
            }
          end

          # Get variant option images
          variant_option_images = product.variant_types.flat_map do |variant_type|
            variant_type.variant_options.flat_map do |variant_option|
              variant_option.images.order(created_at: :desc).map do |image|
                {
                  id: image.id,
                  url: image.url,
                  owner_type: "VariantOption",
                  owner_id: variant_option.id,
                  variant_option_name: variant_option.name,
                  variant_type_id: variant_type.id,
                  variant_type_name: variant_type.name,
                  created_at: image.created_at.iso8601,
                  updated_at: image.updated_at.iso8601
                }
              end
            end
          end

          # Combine all images: product images first, then variant option images
          product_images + variant_option_images
        end
      end
    end
  end
end
