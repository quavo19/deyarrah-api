class AffiliateProfile < ApplicationRecord
  STATUSES = %w[pending approved rejected suspended].freeze
  ACTIVE_STATUSES = %w[pending approved suspended].freeze
  REAPPLICATION_WAIT_PERIOD = 2.weeks
  STATUS_LABELS = {
    "pending" => "Pending Review",
    "approved" => "Approved",
    "rejected" => "Rejected",
    "suspended" => "Suspended"
  }.freeze

  belongs_to :user
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :affiliate_code, presence: true, uniqueness: true
  validates :full_name, :email, :phone, :country, :city, :content_niche, :reason, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :audience_size, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :terms_accepted, acceptance: true
  validate :social_links_are_present
  validate :promotion_channels_are_present
  validate :payout_details_are_present

  before_validation :ensure_affiliate_code

  scope :active_application, -> { where(status: ACTIVE_STATUSES) }

  def active_application?
    ACTIVE_STATUSES.include?(status)
  end

  def reapplication_available_at
    return nil unless status == "rejected"

    (reviewed_at || updated_at || Time.current) + REAPPLICATION_WAIT_PERIOD
  end

  def can_reapply?
    return true unless persisted?
    return false if active_application?
    return true unless status == "rejected"

    Time.current >= reapplication_available_at
  end

  def reapplication_block_reason
    if status == "pending"
      "Your affiliate application is already under review."
    elsif status == "approved"
      "Your affiliate application is already approved."
    elsif status == "suspended"
      "Your affiliate account is suspended and cannot submit a new application."
    elsif status == "rejected" && !can_reapply?
      "You can submit another affiliate application 2 weeks after the last denial."
    end
  end

  def status_label
    STATUS_LABELS.fetch(status, status.to_s.humanize)
  end

  def approve!(reviewer)
    transaction do
      update!(
        status: "approved",
        reviewed_by: reviewer,
        reviewed_at: Time.current,
        rejection_reason: nil,
        suspended_at: nil
      )

      affiliate_role = Role.find_or_create_by!(name: "AFFILIATE") do |role|
        role.description = "Affiliate marketer with customer shopping access and affiliate selling privileges"
      end

      user.update!(role: affiliate_role)
    end
  end

  def reject!(reviewer, reason = nil)
    update!(
      status: "rejected",
      reviewed_by: reviewer,
      reviewed_at: Time.current,
      rejection_reason: reason,
      suspended_at: nil
    )
  end

  def suspend!(reviewer, reason = nil)
    transaction do
      update!(
        status: "suspended",
        reviewed_by: reviewer,
        reviewed_at: Time.current,
        rejection_reason: reason,
        suspended_at: Time.current
      )

      customer_role = Role.find_by(name: "CUSTOMER")
      user.update!(role: customer_role) if customer_role
      user.affiliate_earnings.where(status: %w[pending available]).update_all(status: "cancelled", updated_at: Time.current)
      user.affiliate_withdrawals.where(status: "pending").update_all(status: "cancelled", reviewed_by_id: reviewer&.id, reviewed_at: Time.current, updated_at: Time.current)
      user.affiliate_attributions.where(converted_at: nil).where("expires_at > ?", Time.current).update_all(expires_at: Time.current, updated_at: Time.current)
    end
  end

  def reactivate!(reviewer)
    approve!(reviewer)
  end

  private

  def ensure_affiliate_code
    return if affiliate_code.present?

    loop do
      self.affiliate_code = SecureRandom.alphanumeric(10).upcase
      break unless self.class.exists?(affiliate_code: affiliate_code)
    end
  end

  def social_links_are_present
    errors.add(:social_links, "must include at least one link") if Array(social_links).reject(&:blank?).empty?
  end

  def promotion_channels_are_present
    errors.add(:promotion_channels, "must include at least one channel") if Array(promotion_channels).reject(&:blank?).empty?
  end

  def payout_details_are_present
    errors.add(:payout_details, "must be provided") if payout_details.blank? || payout_details == {}
  end
end
