class CustomerAddress < ApplicationRecord
  belongs_to :user
  has_many :orders, dependent: :nullify

  validates :name, presence: true
  validates :latitude, inclusion: { in: -90.0..90.0 }, allow_nil: true
  validates :longitude, inclusion: { in: -180.0..180.0 }, allow_nil: true

  scope :default, -> { where(is_default: true) }
  scope :by_user, ->(user) { where(user: user) }

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
end
