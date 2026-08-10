class Booking < ApplicationRecord
  enum :status, {
    pending: "pending",
    confirmed: "confirmed",
    dispatched: "dispatched",
    received: "received",
    returning: "returning",
    completed: "completed",
    cancelled: "cancelled"
  }

  attribute :payment_status, :string
  enum :payment_status, {
    pending: "pending",
    completed: "completed"
  }, prefix: true

  belongs_to :user
  belongs_to :product, optional: true
  belongs_to :customer_address, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true
  has_many :booking_items, dependent: :destroy
  has_many :variant_stocks, through: :booking_items
  has_many :transactions, dependent: :destroy
  has_many :fulfillments, dependent: :destroy
  has_many :warehouses, through: :fulfillments

  validates :start_at, presence: true
  validates :end_at, presence: true
  validates :status, presence: true
  validates :payment_status, presence: true
  validate :end_after_start
  validate :has_booking_items
  validate :requires_payment_before_confirmation, if: :will_save_change_to_status?

  after_create :send_creation_email
  after_update :release_stock_if_completed_or_cancelled, if: :saved_change_to_status?
  after_update :send_status_emails, if: :saved_change_to_status?
  after_update :send_assignment_email, if: :saved_change_to_assigned_to_id?

  scope :overlapping, ->(start_at, end_at) {
    where("start_at < ? AND end_at > ?", end_at, start_at)
  }

  scope :active, -> { where(status: [ :pending, :confirmed, :dispatched, :received, :returning ]) }
  scope :confirmed, -> { where(status: :confirmed) }

  def total_price
    total_amount.present? && total_amount > 0 ? total_amount : booking_items.sum { |item| item.price }
  end

  def paid?
    transactions.exists?(status: "success")
  end

  def requires_payment?
    total_price > 0 && !paid?
  end

  private

  def end_after_start
    return unless start_at.present? && end_at.present?
    if end_at <= start_at
      errors.add(:end_at, "must be after start_at")
    end
  end

  def has_booking_items
    if booking_items.empty?
      errors.add(:base, "must have at least one booking_item")
    end
  end

  def requires_payment_before_confirmation
    # Only validate if status is changing to confirmed
    return unless status == "confirmed" && status_before_last_save != "confirmed"

    # Allow confirmation if there's a successful transaction (payment completed)
    return if paid?

    # Allow confirmation if user has CAN_PAY_ON_DELIVERY permission
    return if user.has_permission?("CAN_PAY_ON_DELIVERY")

    # If booking has a price > 0 and user doesn't have permission, payment is required
    if total_price > 0
      errors.add(:status, "cannot be confirmed without successful payment")
    end
  end

  def release_stock_if_completed_or_cancelled
    # Only release stock if status changed to completed or cancelled
    previous_status = status_before_last_save
    return unless (completed? || cancelled?) && previous_status != "completed" && previous_status != "cancelled"

    # Only restore stock for booking_items that still have variant_stock_id
    # (variant_stock might have been deleted)
    restorations = booking_items
      .select { |item| item.variant_stock_id.present? }
      .map do |booking_item|
        {
          variant_stock_id: booking_item.variant_stock_id,
          quantity: booking_item.quantity
        }
      end

    return if restorations.empty?

    # Ensure Redis is initialized for all variant stocks
    variant_stock_ids = restorations.map { |r| r[:variant_stock_id] }.uniq
    VariantStock.where(id: variant_stock_ids).each do |vs|
      total = AvailabilityStore.get_total_quantity(vs.id)
      if total.nil?
        AvailabilityStore.initialize_from_db(vs)
      end
    end

    # Release the reserved quantities
    begin
      AvailabilityStore.atomic_multi_restore(restorations)
    rescue StandardError => e
      status_label = completed? ? "completed" : "cancelled"
      Rails.logger.error("Failed to release stock for #{status_label} booking #{id}: #{e.message}")
      # Don't raise - allow the booking to be marked as completed/cancelled even if Redis fails
    end
  end

  def send_status_emails
    previous_status = status_before_last_save
    return if previous_status == status

    # Send email for booking status change
    case status
    when "cancelled"
      BookingMailer.booking_canceled(self).deliver_later
    when "confirmed"
      BookingMailer.booking_confirmed(self).deliver_later
    when "dispatched"
      BookingMailer.booking_dispatched(self).deliver_later
    when "received"
      BookingMailer.booking_received(self).deliver_later
    when "returning"
      BookingMailer.booking_returning(self).deliver_later
    when "completed"
      BookingMailer.booking_completed(self).deliver_later
    end

    # Also update all fulfillments with the same status and send emails for each
    fulfillments.each do |fulfillment|
      next if fulfillment.status == status

      fulfillment.update_column(:status, status)
      # Send fulfillment-specific email
      case status
      when "confirmed"
        BookingMailer.booking_confirmed(self, fulfillment).deliver_later
      when "dispatched"
        BookingMailer.booking_dispatched(self, fulfillment).deliver_later
      when "received"
        BookingMailer.booking_received(self, fulfillment).deliver_later
      when "returning"
        BookingMailer.booking_returning(self, fulfillment).deliver_later
      when "completed"
        BookingMailer.booking_completed(self, fulfillment).deliver_later
      end
    end
  end

  def send_assignment_email
    return unless assigned_to_id.present? && saved_change_to_assigned_to_id?

    BookingMailer.booking_assigned(self).deliver_later
  end

  def send_creation_email
    BookingMailer.booking_created(self).deliver_later
    BookingMailer.booking_created_customer(self).deliver_later
  end
end
