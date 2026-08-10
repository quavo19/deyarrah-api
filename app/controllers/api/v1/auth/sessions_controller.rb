module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        respond_to :json
        skip_before_action :verify_signed_out_user, only: :destroy
        include Devise::Controllers::Helpers

        def create
          revoke_current_token if warden.authenticated?(:user)
          warden.logout(:user) if warden.authenticated?(:user)

          email = params[:user]&.dig(:email) || params.dig(:session, :user, :email)
          password = params[:user]&.dig(:password) || params.dig(:session, :user, :password)

          if email.blank? || password.blank?
            render json: { error: "Email and password are required." }, status: :unprocessable_entity
            return
          end

          user = User.find_by(email: email)
          unless user && user.valid_password?(password)
            render json: { error: "Invalid email or password." }, status: :unauthorized
            return
          end

          user = User.find(user.id)

          if user.blocked?
            render json: { error: "Your account has been blocked. Please contact support." }, status: :forbidden
            return
          end

          if user.otp_enabled == true
            user.enable_otp! if user.otp_secret.blank?
            user.reload
            user.update(otp_verified_at: nil)
            otp_code = user.generate_otp

            unless otp_code
              render json: { error: "Unable to generate OTP. Please contact support." }, status: :internal_server_error
              return
            end

            OtpEmailJob.perform_later(user.id, otp_code)
            render json: {
              message: "OTP code sent to your email. Please verify to complete login.",
              requires_otp: true,
              user_id: user.id
            }, status: :ok
            return
          end

          sign_in(resource_name, user, store: false)
          respond_with(user)
        end

        private

        def respond_with(current_user, _opts = {})
          token = generate_jwt_token_for_user(current_user)
          response.headers["Authorization"] = "Bearer #{token}"

          render json: {
            status: {
              code: 200,
              message: "Logged in successfully."
            },
            data: UserSerializer.new(current_user).serializable_hash[:data][:attributes],
            token: token
          }, status: :ok
        end


        def extract_token_from_header
          auth_header = request.headers["Authorization"]
          return nil unless auth_header
          auth_header.split(" ").last if auth_header.start_with?("Bearer ")
        end

        def decode_jwt_token_for_logout(token)
          secret = Rails.application.credentials.devise_jwt_secret_key || Rails.application.secret_key_base
          decoded = JWT.decode(token, secret, true, algorithm: "HS256").first
          decoded
        rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError
          nil
        end

        def generate_jwt_token_for_user(user)
          secret = Rails.application.credentials.devise_jwt_secret_key || Rails.application.secret_key_base
          payload = {
            sub: user.id.to_s,
            user_id: user.id.to_s,
            exp: 1.day.from_now.to_i,
            jti: SecureRandom.uuid
          }
          JWT.encode(payload, secret, "HS256")
        end
      end
    end
  end
end
