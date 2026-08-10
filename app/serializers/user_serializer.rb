class UserSerializer
  include JSONAPI::Serializer

  attributes :id, :email, :first_name, :last_name, :avatar, :blocked, :otp_enabled, :created_at, :updated_at

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
end
