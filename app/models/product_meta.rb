class ProductMeta < ApplicationRecord
  self.table_name = "product_meta"

  belongs_to :product

  validates :name, presence: true
  validates :value, presence: true
end
