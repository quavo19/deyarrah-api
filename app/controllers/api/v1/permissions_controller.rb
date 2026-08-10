module Api
  module V1
    class PermissionsController < BaseController
      before_action :authenticate_admin!

      def index
        @permissions = Permission.all.order(:name)
        render json: {
          data: @permissions.map do |permission|
            {
              id: permission.id,
              name: permission.name
            }
          end
        }, status: :ok
      end
    end
  end
end
