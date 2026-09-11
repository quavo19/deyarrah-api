class Badge < ApplicationRecord
  has_many :user_badges, dependent: :destroy
  has_many :users, through: :user_badges

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :bonus_points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
