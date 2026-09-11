module Api
  module V1
    module Products
      class ReviewsController < BaseController
        before_action :authenticate_user!
        before_action :set_product
        before_action :set_review, only: [ :destroy ]

        def index
          authorize Review

          reviews = policy_scope(@product.reviews)
            .includes(:user)
            .order(created_at: :desc)

          render json: {
            data: reviews.map { |review| review_json(review) },
            meta: review_meta(@product)
          }, status: :ok
        end

        def create
          review = @product.reviews.build(review_params)
          review.user = current_user
          authorize review

          if review.save
            render json: { data: review_json(review), meta: review_meta(@product) }, status: :created
          else
            render json: { error: "Validation failed", errors: review.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          authorize @review
          @review.destroy

          render json: { data: review_json(@review), meta: review_meta(@product) }, status: :ok
        end

        private

        def set_product
          @product = Product.find(params[:product_id])
        end

        def set_review
          @review = @product.reviews.includes(:user).find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Review not found" }, status: :not_found
          nil
        end

        def review_params
          params.require(:review).permit(:points, :comment)
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
