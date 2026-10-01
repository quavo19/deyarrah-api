class DeliveryZone < ApplicationRecord
  PRICING_ZONES = %w[near far].freeze

  validates :name, :code, :pricing_zone, :region, presence: true
  validates :code, uniqueness: true
  validates :pricing_zone, inclusion: { in: PRICING_ZONES }
  validate :closed_levels_have_required_children

  scope :active, -> { where(active: true) }

  before_validation :normalize_fields

  def self.resolve(region:, city:, town: nil, market_name: nil)
    normalized_region = normalize_location(region)
    normalized_city = normalize_location(city)
    normalized_town = normalize_location(town)

    active.to_a
      .select { |zone| zone.matches_location?(normalized_region, normalized_city, normalized_town, market_name) }
      .max_by(&:specificity_score)
  end

  def matches_location?(normalized_region, normalized_city, normalized_town = nil, _market_name = nil)
    zone_region = self.class.normalize_location(region)
    zone_city = self.class.normalize_location(city)
    zone_town = self.class.normalize_location(town)

    return false if zone_region.blank? || zone_region != normalized_region
    return true if region_open?

    return false if zone_city.blank? || zone_city != normalized_city
    return true if city_open?

    return false if zone_town.blank? || zone_town != normalized_town
    return true if town_open?

    true
  end

  def specificity_score
    return 4 if market_name.present?
    return 3 if town.present?
    return 2 if city.present?
    1
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
    self.town = town.to_s.strip.presence
    self.market_name = market_name.to_s.strip.presence
    self.station_name = station_name.to_s.strip.presence
  end

  def closed_levels_have_required_children
    return if region.blank?

    if !region_open? && city.blank?
      errors.add(:city, "is required when the region is closed")
    end

    if city.present? && !city_open? && !region_open? && town.blank?
      errors.add(:town, "is required when the city is closed")
    end

  end
end
