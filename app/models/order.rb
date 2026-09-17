class Order < ApplicationRecord
  ORDER_ID_LENGTH = 7
  ORDER_ID_ALPHABET = [ *"A".."Z", *"0".."9" ].freeze

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
  belongs_to :customer_address, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true
  has_many :order_items, dependent: :destroy
  has_many :variant_stocks, through: :order_items
  has_many :transactions, dependent: :destroy
  has_many :fulfillments, dependent: :destroy
  has_many :warehouses, through: :fulfillments
  has_many :affiliate_earnings, dependent: :restrict_with_error

  validates :status, presence: true
  validates :payment_status, presence: true
  validates :order_id, presence: true, uniqueness: true
  validate :has_order_items
  validate :requires_payment_before_confirmation, if: :will_save_change_to_status?

  before_validation :ensure_order_id, on: :create
  after_create :send_creation_email
  after_update :send_status_emails, if: :saved_change_to_status?
  after_update :send_assignment_email, if: :saved_change_to_assigned_to_id?

  scope :active, -> { where(status: [ :pending, :confirmed, :dispatched, :received, :returning ]) }
  scope :confirmed, -> { where(status: :confirmed) }

  def total_price
    total_amount.present? && total_amount > 0 ? total_amount : order_items.sum { |item| item.price }
  end

  def paid?
    transactions.exists?(status: "success")
  end

  def requires_payment?
    total_price > 0 && !paid?
  end

  def award_product_bonus_points!
    return if bonus_points_awarded_at.present?

    points = order_items.includes(variant_stock: :product).sum do |item|
      item.variant_stock&.product&.bonus_points.to_i * item.quantity.to_i
    end

    transaction do
      lock!
      if bonus_points_awarded_at.blank?
        if points.positive?
          user.ensure_bonus
          user.bonus.with_lock do
            user.bonus.update!(balance: user.bonus.balance + points)
          end
        end

        update_column(:bonus_points_awarded_at, Time.current)
      end
    end
  end

  def award_received_bonus_point!
    return if received_bonus_awarded_at.present?

    transaction do
      lock!
      if received_bonus_awarded_at.blank?
        user.ensure_bonus
        user.bonus.with_lock do
          user.bonus.update!(balance: user.bonus.balance + 1)
        end

        update_column(:received_bonus_awarded_at, Time.current)
      end
    end
  end

  private

  def ensure_order_id
    return if order_id.present?

    loop do
      self.order_id = Array.new(ORDER_ID_LENGTH) { ORDER_ID_ALPHABET.sample }.join
      break unless self.class.exists?(order_id: order_id)
    end
  end

  def has_order_items
    if order_items.empty?
      errors.add(:base, "must have at least one order_item")
    end
  end

  def requires_payment_before_confirmation
    # Only validate if status is changing to confirmed
    return unless status == "confirmed" && status_before_last_save != "confirmed"

    # Allow confirmation if there's a successful transaction (payment completed)
    return if paid?

    # Allow confirmation if user has CAN_PAY_ON_DELIVERY permission
    return if user.has_permission?("CAN_PAY_ON_DELIVERY")

    # If order has a price > 0 and user doesn't have permission, payment is required
    if total_price > 0
      errors.add(:status, "cannot be confirmed without successful payment")
    end
  end

  def send_status_emails
    previous_status = status_before_last_save
    return if previous_status == status

    # Send email for order status change
    case status
    when "cancelled"
      OrderMailer.order_canceled(self).deliver_later
    when "confirmed"
      OrderMailer.order_confirmed(self).deliver_later
    when "dispatched"
      OrderMailer.order_dispatched(self).deliver_later
    when "received"
      OrderMailer.order_received(self).deliver_later
    when "returning"
      OrderMailer.order_returning(self).deliver_later
    when "completed"
      OrderMailer.order_completed(self).deliver_later
    end

    # Also update all fulfillments with the same status and send emails for each
    fulfillments.each do |fulfillment|
      next if fulfillment.status == status

      fulfillment.update_column(:status, status)
      # Send fulfillment-specific email
      case status
      when "confirmed"
        OrderMailer.order_confirmed(self, fulfillment).deliver_later
      when "dispatched"
        OrderMailer.order_dispatched(self, fulfillment).deliver_later
      when "received"
        OrderMailer.order_received(self, fulfillment).deliver_later
      when "returning"
        OrderMailer.order_returning(self, fulfillment).deliver_later
      when "completed"
        OrderMailer.order_completed(self, fulfillment).deliver_later
      end
    end
  end

  def send_assignment_email
    return unless assigned_to_id.present? && saved_change_to_assigned_to_id?

    OrderMailer.order_assigned(self).deliver_later
  end

  def send_creation_email
    OrderMailer.order_created(self).deliver_later
    OrderMailer.order_created_customer(self).deliver_later
  end
end
