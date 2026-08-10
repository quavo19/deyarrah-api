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
  belongs_to :booking
  belongs_to :warehouse
  has_many :fulfillment_items, dependent: :destroy
  has_many :booking_items, through: :fulfillment_items

  validates :status, presence: true
  validates :warehouse_id, presence: true
  validates :booking_id, presence: true

  after_update :send_status_emails, if: :saved_change_to_status?

  private

  def send_status_emails
    previous_status = status_before_last_save
    return if previous_status == status

    # Send email for fulfillment status change
    case status
    when "confirmed"
      BookingMailer.booking_confirmed(booking, self).deliver_later
    when "dispatched"
      BookingMailer.booking_dispatched(booking, self).deliver_later
    when "received"
      BookingMailer.booking_received(booking, self).deliver_later
    when "returning"
      BookingMailer.booking_returning(booking, self).deliver_later
    when "completed"
      BookingMailer.booking_completed(booking, self).deliver_later
    end
  end
end
