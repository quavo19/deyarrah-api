class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :variant_stock, optional: true
  has_one :affiliate_earning, dependent: :restrict_with_error

  validates :quantity, presence: true, numericality: { greater_than: 0 }

  def price
    item_price = variant_stock&.price || variant_stock_price || BigDecimal("0")
    item_price * quantity
  end
end
