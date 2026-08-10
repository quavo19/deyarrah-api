module Api
  module V1
    module Auth
      class PasswordsController < Devise::PasswordsController
        respond_to :json

        def create
          self.resource = resource_class.send_reset_password_instructions(resource_params)

          if successfully_sent?(resource)
            render json: {
              message: "If your email address exists in our database, you will receive a password reset link at that email address in a few minutes."
            }, status: :ok
          else
            render json: {
              error: resource.errors.full_messages.to_sentence
            }, status: :unprocessable_entity
          end
        end

        def update
          self.resource = resource_class.reset_password_by_token(resource_params)

          if resource.errors.empty?
            resource.unlock_access! if unlockable?(resource)
            render json: {
              message: "Your password has been changed successfully. You are now signed in.",
              status: {
                code: 200,
                message: "Password reset successfully."
              },
              data: UserSerializer.new(resource.reload).serializable_hash[:data][:attributes]
            }, status: :ok
          else
            render json: {
              error: resource.errors.full_messages.to_sentence
            }, status: :unprocessable_entity
          end
        end

        private

        def resource_params
          params.require(:user).permit(:email, :password, :password_confirmation, :reset_password_token)
        end
      end
    end
  end
end
