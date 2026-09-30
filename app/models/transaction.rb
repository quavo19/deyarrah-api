class Transaction < ApplicationRecord
  PURPOSES = %w[order_payment affiliate_withdrawal_payout].freeze
  DIRECTIONS = %w[credit debit].freeze

  enum :status, {
    initialized: "initialized",
    pending: "pending",
    success: "success",
    failed: "failed"
  }

  belongs_to :order, optional: true
  belongs_to :user, optional: true
  belongs_to :affiliate_withdrawal, optional: true

  validates :amount_kobo, presence: true
  validates :currency, presence: true
  validates :provider, presence: true
  validates :provider_reference, presence: true, uniqueness: true
  validates :purpose, presence: true, inclusion: { in: PURPOSES }
  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validate :has_transaction_reference

  before_validation :set_user_from_reference

  private

  def has_transaction_reference
    return if order_id.present? || affiliate_withdrawal_id.present?

    errors.add(:base, "must be linked to an order or affiliate withdrawal")
  end

  def set_user_from_reference
    self.user ||= order&.user || affiliate_withdrawal&.affiliate_user
  end
end
