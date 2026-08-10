module Api
  module V1
    class CategoriesController < BaseController
      before_action :authenticate_user!, except: [ :index ]
      before_action :set_category, only: [ :destroy ]

      def index
        authorize Category
        @categories = policy_scope(Category).order(:name)

        render json: {
          data: @categories.map do |category|
            {
              id: category.id,
              name: category.name
            }
          end
        }, status: :ok
      end

      def create
        authorize Category

        @category = Category.new(category_params)

        if @category.save
          authorize @category
          render json: {
            data: {
              id: @category.id,
              type: "category",
              attributes: {
                name: @category.name,
                description: @category.description,
                created_at: @category.created_at.iso8601,
                updated_at: @category.updated_at.iso8601
              }
            }
          }, status: :created
        else
          render json: {
            error: "Validation failed",
            errors: @category.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @category

        if @category.destroy
          render json: {
            data: {
              id: @category.id,
              type: "category",
              attributes: {
                name: @category.name,
                description: @category.description,
                created_at: @category.created_at.iso8601,
                updated_at: @category.updated_at.iso8601
              }
            }
          }, status: :ok
        else
          render json: {
            error: "Failed to delete category",
            errors: @category.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def set_category
        @category = Category.find(params[:id])
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: "Category not found" }, status: :not_found
        nil
      end

      def category_params
        params.require(:category).permit(:name, :description)
      end
    end
  end
end
