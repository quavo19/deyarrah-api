class VariantType < ApplicationRecord
  belongs_to :product
  has_many :variant_options, dependent: :destroy

  validates :name, presence: true
  validates :pricing_role, inclusion: { in: %w[base modifier], allow_nil: true }

  scope :base, -> { where(pricing_role: "base") }
  scope :modifier, -> { where(pricing_role: "modifier") }
end
