class ApplicationController < ActionController::API
  include Pundit::Authorization
  include ActionController::RespondWith
  include Devise::Controllers::Helpers

  before_action :set_default_response_format
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from JWT::DecodeError, with: :handle_jwt_error

  protected

  def current_user
    token = extract_token_from_header
    if token
      decoded_token = decode_jwt_token(token)
      if decoded_token
        user_id = decoded_token["sub"] || decoded_token["user_id"]
        if user_id
          user = User.find_by(id: user_id)
          return user if user
        end
      end
    end

    warden_user = warden.user(:user)
    return warden_user if warden_user.is_a?(User)

    user_id = if warden_user.is_a?(Array) && warden_user.first.is_a?(Array) && warden_user.first.first.is_a?(String)
      warden_user.first.first
    elsif warden_user.respond_to?(:id)
      warden_user.id
    end

    User.find_by(id: user_id) if user_id
  end

  def authenticate_user!
    user = current_user

    unless user.is_a?(User)
      render json: {
        message: "You need to sign in or sign up before continuing.",
        error: "Unauthorized"
      }, status: :unauthorized
      return
    end

    if user.blocked?
      render json: {
        message: "Your account has been blocked. Please contact support.",
        error: "Forbidden"
      }, status: :forbidden
      nil
    end
  end

  def authenticate_admin!
    authenticate_user!
    return if performed?

    unless current_user.has_role?("ADMIN") || current_user.has_role?("SUPER_ADMIN")
      render json: {
        message: "You are not authorized to perform this action. Admin access required.",
        error: "Forbidden"
      }, status: :forbidden
      nil
    end
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

  private

  def set_default_response_format
    request.format = :json
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name, :avatar, :role_id ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name, :avatar, :role_id ])
  end

  def extract_token_from_header
    auth_header = request.headers["Authorization"]
    return nil unless auth_header
    auth_header.split(" ").last if auth_header.start_with?("Bearer ")
  end

  def decode_jwt_token(token)
    secret = Rails.application.credentials.devise_jwt_secret_key || Rails.application.secret_key_base
    decoded = JWT.decode(token, secret, true, algorithm: "HS256").first
    jti = decoded["jti"]
    return nil if jti && JwtDenylist.exists?(jti: jti)
    decoded
  rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError
    nil
  end

  def user_not_authorized
    render json: { message: "You are not authorized to perform this action" }, status: :forbidden
  end

  def handle_jwt_error(exception)
    render json: { error: "Invalid or expired token" }, status: :unauthorized
  end
end
