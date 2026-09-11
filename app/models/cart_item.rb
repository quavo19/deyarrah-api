class CartItem < ApplicationRecord
  belongs_to :user
  belongs_to :product
  belongs_to :variant_stock, optional: true

  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :user_id, uniqueness: { scope: [ :product_id, :variant_stock_id ] }
  validate :variant_stock_belongs_to_product

  private

  def variant_stock_belongs_to_product
    return unless variant_stock_id.present? && product_id.present?
    return if variant_stock&.product_id == product_id

    errors.add(:variant_stock_id, "does not belong to this product")
  end
end
