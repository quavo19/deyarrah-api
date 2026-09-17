class UserSerializer
  include JSONAPI::Serializer

  attributes :id, :email, :first_name, :last_name, :avatar, :avatar_storage_key, :phone_numbers, :blocked, :otp_enabled, :created_at, :updated_at

  belongs_to :role, serializer: :role
  has_many :permissions, serializer: :permission

  attribute :role do |user|
    {
      id: user.role&.id,
      name: user.role&.name,
      description: user.role&.description
    }
  end

  attribute :permissions do |user|
    user.permissions.map do |permission|
      {
        id: permission.id,
        name: permission.name
      }
    end
  end

  attribute :addresses do |user|
    user.customer_addresses.map do |address|
      {
        id: address.id,
        name: address.name,
        latitude: address.latitude,
        longitude: address.longitude,
        country: address.country,
        region: address.region,
        city: address.city,
        county: address.county,
        address: address.address,
        is_default: address.is_default,
        created_at: address.created_at,
        updated_at: address.updated_at
      }
    end
  end

  attribute :bonus do |user|
    bonus = user.bonus
    {
      id: bonus&.id,
      balance: bonus&.balance || 0
    }
  end

  attribute :badges do |user|
    user.badges.map do |badge|
      user_badge = user.user_badges.find { |record| record.badge_id == badge.id }

      {
        id: badge.id,
        name: badge.name,
        description: badge.description,
        bonus_points: badge.bonus_points,
        unlocked_at: user_badge&.created_at
      }
    end
  end
end
