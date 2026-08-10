require "rotp"

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  # Associations
  belongs_to :role, optional: true
  has_many :user_permissions, dependent: :destroy
  has_many :permissions, through: :user_permissions
  has_many :bookings, dependent: :destroy
  has_many :customer_addresses, dependent: :destroy

  # Validations
  validate :user_not_blocked, on: :create

  # Callbacks
  before_create :set_default_role

  # Override Devise's password reset email to use our custom mailer via background job
  def send_reset_password_instructions(opts = {})
    token = set_reset_password_token
    if token && persisted?
      PasswordResetEmailJob.perform_later(id, token)
    end
    token
  end

  DEFAULT_ROLE_ID = "97921d3e-d734-45aa-86da-a2267c68d15d"
  OTP_INTERVAL = 300

  # OTP Methods
  def enable_otp!
    self.otp_secret = ROTP::Base32.random
    self.otp_enabled = true
    save!
  end

  def disable_otp!
    self.otp_enabled = false
    self.otp_secret = nil
    self.otp_verified_at = nil
    save!
  end

  def generate_otp
    return nil unless otp_enabled && otp_secret.present?
    totp = ROTP::TOTP.new(otp_secret, interval: OTP_INTERVAL)
    totp.now
  end

  def verify_otp(otp_code)
    return false unless otp_enabled && otp_secret.present?
    totp = ROTP::TOTP.new(otp_secret, interval: OTP_INTERVAL)
    result = totp.verify(otp_code, drift_behind: 1, drift_ahead: 1)
    if result
      self.otp_verified_at = Time.current
      save!
    end
    result
  end

  def has_permission?(permission_name)
    permissions.exists?(name: permission_name)
  end

  def has_role?(role_name)
    role&.name == role_name.to_s
  end

  private

  def set_default_role
    self.role ||= Role.find_by(id: DEFAULT_ROLE_ID)
  end

  def user_not_blocked
    if blocked?
      errors.add(:base, "User account is blocked")
    end
  end
end
