class SubCategory < ApplicationRecord
  belongs_to :category
  has_many :product_sub_categories, dependent: :destroy
  has_many :products, through: :product_sub_categories

  validates :name, presence: true, uniqueness: { scope: :category_id, case_sensitive: false }
end
