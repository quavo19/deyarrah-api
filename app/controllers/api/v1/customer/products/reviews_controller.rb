module Api
  module V1
    module Customer
      module Products
        class ReviewsController < BaseController
          before_action :authenticate_user!
          before_action :set_product

          def index
            return if performed?

            reviews = @product.reviews.includes(:user).order(created_at: :desc)

            render json: {
              data: reviews.map { |review| review_json(review) },
              meta: review_meta(@product)
            }, status: :ok
          end

          def create
            return if performed?

            unless purchased_and_received?
              render json: { error: "You can review this product after receiving an order that includes it." }, status: :forbidden
              return
            end

            review = @product.reviews.find_or_initialize_by(user: current_user)
            review.assign_attributes(review_params)

            if review.save
              render json: { data: review_json(review), meta: review_meta(@product) }, status: review.previously_new_record? ? :created : :ok
            else
              render json: { error: "Validation failed", errors: review.errors.full_messages }, status: :unprocessable_entity
            end
          end

          private

          def set_product
            @product = Product.where(active: true).find_by(id: params[:product_id])
            return if @product

            render json: { error: "Product not found" }, status: :not_found
          end

          def review_params
            params.require(:review).permit(:points, :comment)
          end

          def purchased_and_received?
            current_user.orders
              .where(status: [ :received, :completed ])
              .joins(order_items: :variant_stock)
              .where(variant_stocks: { product_id: @product.id })
              .exists?
          end

          def review_json(review)
            {
              id: review.id,
              type: "review",
              attributes: {
                product_id: review.product_id,
                user_id: review.user_id,
                points: review.points,
                comment: review.comment,
                user: {
                  id: review.user.id,
                  email: review.user.email,
                  first_name: review.user.first_name,
                  last_name: review.user.last_name,
                  avatar: review.user.avatar
                },
                created_at: review.created_at.iso8601,
                updated_at: review.updated_at.iso8601
              }
            }
          end

          def review_meta(product)
            reviews = product.reviews
            count = reviews.count
            average = count.positive? ? reviews.average(:points).to_f.round(2) : 0.0

            {
              average_points: average,
              total_reviews: count
            }
          end
        end
      end
    end
  end
end
