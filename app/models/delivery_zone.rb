class DeliveryZone < ApplicationRecord
  PRICING_ZONES = %w[near far].freeze

  validates :name, :code, :pricing_zone, presence: true
  validates :code, uniqueness: true
  validates :pricing_zone, inclusion: { in: PRICING_ZONES }

  scope :active, -> { where(active: true) }

  before_validation :normalize_fields

  def self.resolve(region:, city:)
    normalized_region = normalize_location(region)
    normalized_city = normalize_location(city)

    active.order(Arel.sql("CASE WHEN city IS NULL OR city = '' THEN 1 ELSE 0 END"), :name).find do |zone|
      zone.matches_location?(normalized_region, normalized_city)
    end
  end

  def matches_location?(normalized_region, normalized_city)
    zone_region = self.class.normalize_location(region)
    zone_city = self.class.normalize_location(city)

    return false if zone_region.present? && zone_region != normalized_region
    return false if zone_city.present? && zone_city != normalized_city

    zone_region.present? || zone_city.present?
  end

  def self.normalize_location(value)
    value.to_s.strip.downcase.squeeze(" ")
  end

  private

  def normalize_fields
    self.code = code.to_s.strip.parameterize(separator: "_") if code.present?
    self.pricing_zone = pricing_zone.to_s.strip.downcase if pricing_zone.present?
    self.region = region.to_s.strip.presence
    self.city = city.to_s.strip.presence
    self.station_name = station_name.to_s.strip.presence
  end
end
