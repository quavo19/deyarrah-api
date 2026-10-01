class CustomerAddress < ApplicationRecord
  belongs_to :user
  has_many :orders, dependent: :nullify

  validates :name, presence: true
  validates :latitude, inclusion: { in: -90.0..90.0 }, allow_nil: true
  validates :longitude, inclusion: { in: -180.0..180.0 }, allow_nil: true
  validates :region, presence: true
  validate :delivery_zone_is_available

  scope :default, -> { where(is_default: true) }
  scope :by_user, ->(user) { where(user: user) }

  before_validation :normalize_location_fields
  before_validation :assign_delivery_zone
  before_create :default_first_address

  # Set location from latitude and longitude
  def set_location_from_coords(lat, lon)
    return unless lat.present? && lon.present?
    self.latitude = lat.to_f
    self.longitude = lon.to_f
  end

  # Set as default address for user (ensures only one default per user)
  def set_as_default!
    CustomerAddress.transaction do
      user.customer_addresses.update_all(is_default: false)
      update!(is_default: true)
    end
  end

  private

  def normalize_location_fields
    self.country = country.to_s.strip.presence || "Ghana"
    self.region = region.to_s.strip.presence
    self.city = city.to_s.strip.presence
    self.town = town.to_s.strip.presence if respond_to?(:town=)
    self.market_name = market_name.to_s.strip.presence if respond_to?(:market_name=)
  end

  def assign_delivery_zone
    zone = DeliveryZone.resolve(
      region: region,
      city: city,
      town: town
    )
    self.delivery_zone_id = zone&.id if respond_to?(:delivery_zone_id=)
  end

  def delivery_zone_is_available
    return if region.blank?
    return if delivery_zone_id.present?

    errors.add(:base, "Delivery is not available for this address")
  end

  def default_first_address
    self.is_default = true if user && user.customer_addresses.none?
  end
end
