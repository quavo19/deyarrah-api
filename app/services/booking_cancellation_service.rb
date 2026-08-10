class BookingCancellationService
  class ValidationError < StandardError; end

  def initialize(booking)
    @booking = booking
  end

  def cancel
    if @booking.cancelled?
      raise ValidationError, "booking is already cancelled"
    end

    ActiveRecord::Base.transaction do
      @booking.update!(status: :cancelled)
      restore_redis_quantities
      @booking.reload
    end
  end

  private

  def restore_redis_quantities
    restorations = @booking.booking_items.map do |booking_item|
      {
        variant_stock_id: booking_item.variant_stock_id,
        quantity: booking_item.quantity
      }
    end

    AvailabilityStore.atomic_multi_restore(restorations)
  end
end
