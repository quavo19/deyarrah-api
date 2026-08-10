module Api
  module V1
    module Users
      class OtpController < BaseController
        def verify
          user_id = params[:user_id] || current_user&.id

          if user_id.blank?
            render json: { error: "User ID is required" }, status: :unprocessable_entity
            return
          end

          user = User.find_by(id: user_id)
          unless user
            render json: { error: "User not found" }, status: :not_found
            return
          end

          otp_code = params[:otp_code]
          if otp_code.blank?
            render json: { error: "OTP code is required" }, status: :unprocessable_entity
            return
          end

          unless user.verify_otp(otp_code)
            render json: { error: "Invalid or expired OTP code" }, status: :unauthorized
            return
          end

          user.reload
          unless user.otp_verified_at.present?
            render json: { error: "OTP verification failed. Please try again." }, status: :unauthorized
            return
          end

          sign_in(:user, user, store: false) unless warden.authenticated?(:user)
          token = generate_jwt_token_for_user(user)

          response.headers["Authorization"] = "Bearer #{token}"

          render json: {
            message: "OTP verified successfully",
            status: {
              code: 200,
              message: "Logged in successfully."
            },
            data: UserSerializer.new(user).serializable_hash[:data][:attributes],
            token: token
          }, status: :ok
        end

        def toggle
          authenticate_user!
          return if performed?

          if current_user.otp_enabled?
            current_user.disable_otp!
            message = "OTP disabled successfully. It will not be required for your next login."
          else
            current_user.enable_otp!
            message = "OTP enabled successfully. OTP will be required for your next login."
          end

          render json: { message: message }, status: :ok
        end
      end
    end
  end
end
