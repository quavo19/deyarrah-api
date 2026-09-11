module Api
  module V1
    module Customer
      class WishlistItemsController < BaseController
        before_action :authenticate_user!
        before_action :set_product, only: [ :create ]

        def index
          wishlist_items = current_user.wishlist_items.includes(product: [ :category, :images ]).order(created_at: :desc)

          render json: { data: wishlist_items.map { |item| item_json(item) } }, status: :ok
        end

        def create
          wishlist_item = current_user.wishlist_items.find_or_initialize_by(product: @product)

          if wishlist_item.persisted? || wishlist_item.save
            render json: { data: item_json(wishlist_item) }, status: :created
          else
            render json: { error: "Validation failed", errors: wishlist_item.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          wishlist_item = current_user.wishlist_items.find_by(product_id: params[:id])
          wishlist_item ||= current_user.wishlist_items.find_by(id: params[:id])

          unless wishlist_item
            render json: { error: "Wishlist item not found" }, status: :not_found
            return
          end

          wishlist_item.destroy
          render json: { message: "Removed from wishlist" }, status: :ok
        end

        private

        def set_product
          @product = Product.where(active: true).find_by(id: params[:product_id] || params[:id])
          return if @product

          render json: { error: "Product not found" }, status: :not_found
        end

        def item_json(item)
          product = item.product
          first_image = product.images.order(created_at: :desc).first

          {
            id: item.id,
            type: "wishlist_item",
            attributes: {
              user_id: item.user_id,
              product_id: item.product_id,
              product: {
                id: product.id,
                name: product.name,
                description: product.description,
                active: product.active,
                base_price: product.base_price.to_f,
                bonus_points: product.bonus_points,
                default_variant_stock: default_variant_stock_json(product),
                category: product.category ? { id: product.category.id, name: product.category.name } : nil,
                image_url: first_image&.url
              },
              created_at: item.created_at.iso8601,
              updated_at: item.updated_at.iso8601
            }
          }
        end

        def default_variant_stock_json(product)
          stock = product.variant_stocks
            .includes(:warehouse)
            .sort_by { |variant_stock| [ variant_stock.processed_available_quantity <= 0 ? 1 : 0, variant_stock.created_at ] }
            .first

          return nil unless stock

          {
            id: stock.id,
            warehouse_id: stock.warehouse_id,
            warehouse_name: stock.warehouse&.name,
            available_quantity: stock.processed_available_quantity,
            price: stock.price.to_f
          }
        end
      end
    end
  end
end
