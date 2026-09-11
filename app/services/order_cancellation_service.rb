class OrderCancellationService
  class ValidationError < StandardError; end

  def initialize(order)
    @order = order
  end

  def cancel
    if @order.cancelled?
      raise ValidationError, "order is already cancelled"
    end

    ActiveRecord::Base.transaction do
      @order.update!(status: :cancelled)
      @order.reload
    end
  end
end
