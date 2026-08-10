module Api
  module V1
    module Users
      class PasswordsController < BaseController
        before_action :authenticate_user!

        def update
          old_password = params[:old_password]
          new_password = params[:new_password]

          if old_password.blank?
            render json: {
              error: "Old password is required"
            }, status: :unprocessable_entity
            return
          end

          if new_password.blank?
            render json: {
              error: "New password is required"
            }, status: :unprocessable_entity
            return
          end

          unless current_user.valid_password?(old_password)
            render json: {
              error: "Current password is incorrect"
            }, status: :unauthorized
            return
          end

          if current_user.update(password: new_password)
            render json: {
              status: {
                code: 200,
                message: "Password updated successfully."
              }
            }, status: :ok
          else
            render json: {
              error: current_user.errors.full_messages.to_sentence
            }, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
