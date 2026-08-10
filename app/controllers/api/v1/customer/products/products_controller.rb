module Api
  module V1
    module Customer
      module Products
        class ProductsController < BaseController
          def index
            @products = Product.includes(
              :category,
              :images,
              variant_types: { variant_options: :images }
            ).where(active: true)

            if params[:search].present?
              search_term = "%#{params[:search]}%"
              @products = @products.where("name ILIKE ?", search_term)
            end

            if params[:category].present?
              @products = @products.where(category_id: params[:category])
            end

            if params[:price].present? && %w[asc desc].include?(params[:price].downcase)
              direction = params[:price].downcase == "asc" ? "ASC" : "DESC"
              @products = @products
                .joins("LEFT JOIN variant_types ON variant_types.product_id = products.id AND variant_types.pricing_role = 'base'")
                .joins("LEFT JOIN variant_options ON variant_options.variant_type_id = variant_types.id")
                .group("products.id")
                .order("COALESCE(MIN(variant_options.price), 0) #{direction}")
            else
              @products = @products.order(created_at: :desc)
            end

            page = params[:page] || 1
            per_page = params[:per_page] || 25
            @products = @products.page(page).per(per_page)

            render json: {
              data: @products.map do |product|
                first_image = product.images.order(created_at: :desc).first
                {
                  id: product.id,
                  type: "product",
                  attributes: {
                    name: product.name,
                    description: product.description,
                    bookable_type: product.bookable_type,
                    status: product.status,
                    base_price: product.base_price.to_f,
                    delivery_rate_per_km: product.delivery_rate_per_km.to_f,
                    image_url: first_image&.url,
                    category: product.category ? {
                      id: product.category.id,
                      name: product.category.name
                    } : nil,
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
            @product = Product.includes(
              :category,
              :images,
              :product_meta,
              variant_types: { variant_options: :images }
            ).where(active: true).find(params[:id])

            render json: {
              data: {
                id: @product.id,
                type: "product",
                attributes: {
                  name: @product.name,
                  description: @product.description,
                  bookable_type: @product.bookable_type,
                  status: @product.status,
                  base_price: @product.base_price.to_f,
                  delivery_rate_per_km: @product.delivery_rate_per_km.to_f,
                  category: @product.category ? {
                    id: @product.category.id,
                    name: @product.category.name
                  } : nil,
                  images: format_product_images(@product),
                  meta: format_product_meta(@product),
                  created_at: @product.created_at.iso8601,
                  updated_at: @product.updated_at.iso8601
                }
              }
            }, status: :ok
          rescue ActiveRecord::RecordNotFound
            render json: { error: "Product not found" }, status: :not_found
          end

          private

          def format_product_images(product)
            product.images.order(created_at: :desc).map do |image|
              {
                id: image.id,
                url: image.url,
                owner_type: "Product",
                owner_id: product.id,
                created_at: image.created_at.iso8601,
                updated_at: image.updated_at.iso8601
              }
            end
          end

          def format_product_meta(product)
            product.product_meta.order(:name).map do |meta|
              {
                id: meta.id,
                name: meta.name,
                value: meta.value,
                created_at: meta.created_at.iso8601,
                updated_at: meta.updated_at.iso8601
              }
            end
          end
        end
      end
    end
  end
end
