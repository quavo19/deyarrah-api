class FulfillmentItem < ApplicationRecord
  belongs_to :fulfillment
  belongs_to :booking_item

  validates :fulfillment_id, presence: true
  validates :booking_item_id, presence: true
  validate :booking_item_belongs_to_same_warehouse

  private

  def booking_item_belongs_to_same_warehouse
    return unless fulfillment && booking_item

    booking_item_warehouse_id = booking_item.variant_stock&.warehouse_id
    if booking_item_warehouse_id != fulfillment.warehouse_id
      errors.add(:booking_item, "must belong to the same warehouse as the fulfillment")
    end
  end
end
