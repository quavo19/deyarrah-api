class AffiliateAttribution < ApplicationRecord
  DEFAULT_EXPIRY_DAYS = 30

  belongs_to :affiliate_user, class_name: "User"
  belongs_to :product
  belongs_to :buyer_user, class_name: "User", optional: true
  belongs_to :affiliate_click, optional: true
  has_many :affiliate_earnings, dependent: :nullify

  validates :attributed_at, :expires_at, presence: true
  validate :has_visitor_identity
  validate :affiliate_user_is_active

  before_validation :set_tracking_window

  private

  def set_tracking_window
    self.attributed_at ||= Time.current
    self.expires_at ||= attributed_at + DEFAULT_EXPIRY_DAYS.days if attributed_at.present?
  end

  def has_visitor_identity
    return if buyer_user_id.present? || visitor_id.present?

    errors.add(:base, "must include a buyer user or visitor id")
  end

  def affiliate_user_is_active
    return if affiliate_user&.active_affiliate?

    errors.add(:affiliate_user, "must be an active affiliate")
  end
end
