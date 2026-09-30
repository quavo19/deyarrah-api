class AffiliateSignupReferral < ApplicationRecord
  belongs_to :affiliate_user, class_name: "User"
  belongs_to :referred_user, class_name: "User"
  has_many :affiliate_earnings, dependent: :nullify

  validates :referred_at, presence: true
  validates :rewarded_orders_count, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3 }
  validates :referred_user_id, uniqueness: true
  validate :affiliate_user_is_active
  validate :cannot_refer_self

  before_validation :set_referred_at

  private

  def set_referred_at
    self.referred_at ||= Time.current
  end

  def affiliate_user_is_active
    return if affiliate_user&.active_affiliate?

    errors.add(:affiliate_user, "must be an active affiliate")
  end

  def cannot_refer_self
    return unless affiliate_user_id.present? && affiliate_user_id == referred_user_id

    errors.add(:referred_user, "cannot be the same as affiliate user")
  end
end
