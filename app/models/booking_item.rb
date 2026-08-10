class BookingItem < ApplicationRecord
  belongs_to :booking
  belongs_to :variant_stock, optional: true

  validates :quantity, presence: true, numericality: { greater_than: 0 }

  def price
    days = calculate_booking_days
    # Use stored price if variant_stock is missing (product/variant_stock was deleted)
    item_price = variant_stock&.price || variant_stock_price || BigDecimal("0")
    item_price * quantity * days
  end

  private

  def calculate_booking_days
    return 0.5 unless booking&.start_at.present? && booking&.end_at.present?

    # Calculate duration in hours
    duration_hours = (booking.end_at - booking.start_at) / 1.hour

    # Minimum is 0.5 days (12 hours)
    return 0.5 if duration_hours <= 12

    # Round up to nearest 0.5 day increment (12-hour blocks)
    # 12-24 hours = 1 day, 24-36 hours = 1.5 days, 36-48 hours = 2 days, etc.
    half_day_blocks = (duration_hours / 12.0).ceil
    half_day_blocks * 0.5
  end
end
