module JwtHelpers
  def auth_headers(user)
    token = generate_jwt_token(user)
    { "Authorization" => "Bearer #{token}" }
  end

  def generate_jwt_token(user)
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

# Extend Devise::Test::IntegrationHelpers to add JWT token generation
module Devise::Test::IntegrationHelpers
  alias_method :original_sign_in, :sign_in

  def sign_in(resource_or_scope, resource = nil, options = {})
    # Determine the user from the arguments
    # Devise sign_in can be called as:
    # - sign_in(user) - single argument
    # - sign_in(scope, resource, options) - three arguments
    user = if resource.nil? && !resource_or_scope.is_a?(Symbol)
      # Called as sign_in(user) - single argument, user is the first param
      resource_or_scope
    elsif resource
      # Called as sign_in(scope, resource, options) - resource is the user
      resource
    else
      # Fallback
      resource_or_scope
    end

    # Call original Devise sign_in
    if resource.nil? && !resource_or_scope.is_a?(Symbol)
      # Single argument call
      original_sign_in(resource_or_scope)
    else
      # Three argument call
      original_sign_in(resource_or_scope, resource, options)
    end

    # Generate and store JWT token if user is a User model
    if user.is_a?(User)
      @current_test_user = user
      @jwt_token = generate_jwt_token_for_test(user)
    end
  end

  private

  def generate_jwt_token_for_test(user)
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

RSpec.configure do |config|
  config.include JwtHelpers, type: :request
end

# Monkey patch request methods to automatically include JWT token when available
module ActionDispatch::Integration::RequestHelpers
  %i[get post put patch delete].each do |method_name|
    alias_method "original_#{method_name}_with_jwt", method_name

    define_method method_name do |path, **args|
      # Add JWT token to headers if available from sign_in
      if instance_variable_defined?(:@jwt_token) && @jwt_token
        headers = args[:headers] || {}
        args[:headers] = headers.merge("Authorization" => "Bearer #{@jwt_token}")
      end
      send("original_#{method_name}_with_jwt", path, **args)
    end
  end
end
