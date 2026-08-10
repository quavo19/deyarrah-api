class VariantOption < ApplicationRecord
  belongs_to :variant_type
  has_many :images, as: :owner, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :variant_type_id, case_sensitive: false }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
