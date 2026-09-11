class SupportRequest < ApplicationRecord
  TOPICS = {
    "order_enquiry" => "Order Enquiry",
    "general_support" => "General Support",
    "delivery_issue" => "Delivery Issue",
    "order_mismatch" => "Order Mismatch or Wrong Item Received",
    "payment_issue" => "Payment Issue",
    "product_care" => "Product Care Question",
    "returns_refunds" => "Returns and Refunds"
  }.freeze

  STATUSES = {
    "pending" => "Pending",
    "confirmed" => "Confirmed",
    "resolved" => "Resolved"
  }.freeze

  belongs_to :user, optional: true

  validates :topic, presence: true, inclusion: { in: TOPICS.keys }
  validates :status, presence: true, inclusion: { in: STATUSES.keys }
  validates :message, presence: true, length: { maximum: 5000 }
  validates :guest_full_name, :guest_email, :guest_phone, presence: true, unless: :user_id?
  validates :guest_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  def requester_name
    if user
      [ user.first_name, user.last_name ].compact_blank.join(" ").presence || user.email
    else
      guest_full_name
    end
  end

  def requester_email
    user&.email || guest_email
  end

  def requester_phone
    user&.phone_numbers&.first || guest_phone
  end

  def topic_label
    TOPICS.fetch(topic, topic.to_s.humanize)
  end

  def status_label
    STATUSES.fetch(status, status.to_s.humanize)
  end
end
