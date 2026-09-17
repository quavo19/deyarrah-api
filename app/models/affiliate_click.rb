class AffiliateClick < ApplicationRecord
  belongs_to :affiliate_user, class_name: "User"
  belongs_to :product
  belongs_to :buyer_user, class_name: "User", optional: true
  has_one :affiliate_attribution, dependent: :nullify

  validates :clicked_at, presence: true
  validate :has_visitor_identity
  validate :affiliate_user_is_active

  before_validation :set_clicked_at

  private

  def set_clicked_at
    self.clicked_at ||= Time.current
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
