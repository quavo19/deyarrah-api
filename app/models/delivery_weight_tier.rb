class DeliveryWeightTier < ApplicationRecord
  PRICING_ZONES = DeliveryZone::PRICING_ZONES

  validates :pricing_zone, :min_weight_kg, :fee, presence: true
  validates :pricing_zone, inclusion: { in: PRICING_ZONES }
  validates :min_weight_kg, numericality: { greater_than_or_equal_to: 0 }
  validates :max_weight_kg, numericality: { greater_than: :min_weight_kg }, allow_nil: true
  validates :fee, numericality: { greater_than_or_equal_to: 0 }

  before_validation :normalize_pricing_zone

  scope :for_zone, ->(pricing_zone) { where(pricing_zone: pricing_zone.to_s.downcase) }
  scope :ordered, -> { order(:min_weight_kg) }

  def self.match(pricing_zone:, weight_kg:)
    weight = BigDecimal(weight_kg.to_s)
    for_zone(pricing_zone).ordered.detect do |tier|
      weight >= tier.min_weight_kg && (tier.max_weight_kg.nil? || weight <= tier.max_weight_kg)
    end
  end

  private

  def normalize_pricing_zone
    self.pricing_zone = pricing_zone.to_s.strip.downcase if pricing_zone.present?
  end
end
