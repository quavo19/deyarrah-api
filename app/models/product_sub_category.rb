class ProductSubCategory < ApplicationRecord
  belongs_to :product
  belongs_to :sub_category

  validates :product_id, uniqueness: { scope: :sub_category_id }
end
