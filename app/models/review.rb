class Review < ApplicationRecord
  belongs_to :product
  belongs_to :user

  validates :points, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }
end
