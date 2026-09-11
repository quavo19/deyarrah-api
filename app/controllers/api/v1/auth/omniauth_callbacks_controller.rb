module Api
  module V1
    module Auth
      class OmniauthCallbacksController < Devise::OmniauthCallbacksController
        respond_to :json

        def google_oauth2
          user = User.from_google_omniauth(request.env["omniauth.auth"])

          if user.blocked?
            redirect_to_frontend(error: "Your account has been blocked. Please contact support.")
            return
          end

          sign_in(:user, user, store: false)
          token = generate_jwt_token_for_user(user)
          response.headers["Authorization"] = "Bearer #{token}"

          redirect_to_frontend(token: token)
        rescue ActiveRecord::RecordInvalid => e
          redirect_to_frontend(error: e.record.errors.full_messages.to_sentence)
        rescue ArgumentError => e
          redirect_to_frontend(error: e.message)
        end

        def failure
          redirect_to_frontend(error: params[:message].presence || "Google authentication failed")
        end

        private

        def redirect_to_frontend(token: nil, error: nil)
          query = {}
          query[:token] = token if token.present?
          query[:error] = error if error.present?

          redirect_to "#{frontend_callback_url}?#{query.to_query}", allow_other_host: true
        end

        def frontend_callback_url
          frontend_url = ENV.fetch("CUSTOMER_FRONTEND_URL", ENV.fetch("FRONTEND_URL", "http://localhost:5173")).delete_suffix("/")
          "#{frontend_url}/auth/google/callback"
        end
      end
    end
  end
end
