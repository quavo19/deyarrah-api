class DeliveryHighValueRate < ApplicationRecord
  PRICING_ZONES = DeliveryZone::PRICING_ZONES

  validates :pricing_zone, :shipping_category, :fee, presence: true
  validates :pricing_zone, inclusion: { in: PRICING_ZONES }
  validates :shipping_category, uniqueness: { scope: :pricing_zone }
  validates :fee, numericality: { greater_than_or_equal_to: 0 }

  before_validation :normalize_fields

  def self.for(pricing_zone:, shipping_category:)
    find_by(
      pricing_zone: pricing_zone.to_s.strip.downcase,
      shipping_category: shipping_category.to_s.strip.downcase
    )
  end

  private

  def normalize_fields
    self.pricing_zone = pricing_zone.to_s.strip.downcase if pricing_zone.present?
    self.shipping_category = shipping_category.to_s.strip.downcase if shipping_category.present?
  end
end
