module Api
  module V1
    module Users
      class ProfileController < BaseController
        before_action :authenticate_user!

        def show
          render json: {
            status: {
              code: 200,
              message: "Profile retrieved successfully."
            },
            data: UserSerializer.new(current_user).serializable_hash[:data][:attributes]
          }, status: :ok
        end

        def update
          if current_user.update(profile_params)
            render json: {
              status: {
                code: 200,
                message: "Profile updated successfully."
              },
              data: UserSerializer.new(current_user.reload).serializable_hash[:data][:attributes]
            }, status: :ok
          else
            render json: {
              error: current_user.errors.full_messages.to_sentence
            }, status: :unprocessable_entity
          end
        end

        private

        def profile_params
          permitted = params.require(:user).permit(:first_name, :last_name, :avatar, :email, phone_numbers: [])
          if permitted[:phone_numbers].present?
            permitted[:phone_numbers] = permitted[:phone_numbers].map(&:to_s).map(&:strip).reject(&:blank?).first(3)
          end
          permitted
        end
      end
    end
  end
end
