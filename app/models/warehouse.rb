class Warehouse < ApplicationRecord
  # Location is stored as separate latitude and longitude decimal columns
  # latitude: decimal (precision: 10, scale: 7) - range: -90.0000000 to 90.0000000
  # longitude: decimal (precision: 10, scale: 7) - range: -180.0000000 to 180.0000000

  has_many :images, as: :owner, dependent: :destroy
  has_many :variant_stocks, dependent: :destroy
  has_many :fulfillments, dependent: :destroy

  validates :name, presence: true
  validates :latitude, presence: true, inclusion: { in: -90.0..90.0 }
  validates :longitude, presence: true, inclusion: { in: -180.0..180.0 }

  # Set location from latitude and longitude (public method for controller)
  def set_location_from_coords(lat, lon)
    return unless lat.present? && lon.present?
    self.latitude = lat.to_f
    self.longitude = lon.to_f
  end
end
