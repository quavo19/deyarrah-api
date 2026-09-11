class Fulfillment < ApplicationRecord
  enum :status, {
    pending: "pending",
    confirmed: "confirmed",
    dispatched: "dispatched",
    received: "received",
    returning: "returning",
    completed: "completed",
    cancelled: "cancelled"
  }
  belongs_to :order
  belongs_to :warehouse
  has_many :fulfillment_items, dependent: :destroy
  has_many :order_items, through: :fulfillment_items

  validates :status, presence: true
  validates :warehouse_id, presence: true
  validates :order_id, presence: true

  after_update :send_status_emails, if: :saved_change_to_status?

  private

  def send_status_emails
    previous_status = status_before_last_save
    return if previous_status == status

    # Send email for fulfillment status change
    case status
    when "confirmed"
      OrderMailer.order_confirmed(order, self).deliver_later
    when "dispatched"
      OrderMailer.order_dispatched(order, self).deliver_later
    when "received"
      OrderMailer.order_received(order, self).deliver_later
    when "returning"
      OrderMailer.order_returning(order, self).deliver_later
    when "completed"
      OrderMailer.order_completed(order, self).deliver_later
    end
  end
end
