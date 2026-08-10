module Api
  module V1
    class RolesController < BaseController
      before_action :authenticate_admin!
      before_action :set_role, only: [ :update ]

      def index
        @roles = Role.all.order(:name)
        render json: {
          data: @roles.map do |role|
            {
              id: role.id,
              name: role.name,
              description: role.description
            }
          end
        }, status: :ok
      end

      def update
        if @role.update(role_params)
          render json: {
            data: {
              id: @role.id,
              name: @role.name,
              description: @role.description

            }
          }, status: :ok
        else
          render json: {
            errors: @role.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def set_role
        @role = Role.find(params[:id])
      end

      def role_params
        params.require(:role).permit(:description)
      end
    end
  end
end
