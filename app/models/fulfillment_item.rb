class FulfillmentItem < ApplicationRecord
  belongs_to :fulfillment
  belongs_to :order_item

  validates :fulfillment_id, presence: true
  validates :order_item_id, presence: true
  validate :order_item_belongs_to_same_warehouse

  private

  def order_item_belongs_to_same_warehouse
    return unless fulfillment && order_item

    order_item_warehouse_id = order_item.variant_stock&.warehouse_id
    if order_item_warehouse_id != fulfillment.warehouse_id
      errors.add(:order_item, "must belong to the same warehouse as the fulfillment")
    end
  end
end
