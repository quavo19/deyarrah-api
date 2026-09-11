class Category < ApplicationRecord
  has_many :sub_categories, dependent: :restrict_with_error
  has_many :product_categories, dependent: :destroy
  has_many :products, through: :product_categories

  validates :name, presence: true, uniqueness: true
end
