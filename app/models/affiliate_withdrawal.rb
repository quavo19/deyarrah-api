class AffiliateWithdrawal < ApplicationRecord
  STATUSES = %w[pending approved paid rejected cancelled].freeze

  belongs_to :affiliate_user, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :amount, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :requested_at, presence: true
  validate :affiliate_user_is_active, on: :create

  before_validation :set_requested_at

  private

  def set_requested_at
    self.requested_at ||= Time.current
  end

  def affiliate_user_is_active
    return if affiliate_user&.active_affiliate?

    errors.add(:affiliate_user, "must be an active affiliate")
  end
end
