class AffiliateEarning < ApplicationRecord
  STATUSES = %w[pending available cancelled withdrawn].freeze

  belongs_to :affiliate_user, class_name: "User"
  belongs_to :buyer_user, class_name: "User"
  belongs_to :order
  belongs_to :order_item
  belongs_to :product
  belongs_to :affiliate_attribution, optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :sale_amount, :commission_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :earned_at, presence: true
  validates :order_item_id, uniqueness: true
  validate :affiliate_user_is_active

  before_validation :set_earned_at

  private

  def set_earned_at
    self.earned_at ||= Time.current
  end

  def affiliate_user_is_active
    return if affiliate_user&.active_affiliate?

    errors.add(:affiliate_user, "must be an active affiliate")
  end
end
