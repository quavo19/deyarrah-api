class DeliverySetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.high_value_additional_unit_multiplier
    setting = find_by(key: "high_value_additional_unit_multiplier")
    multiplier = setting&.value&.fetch("multiplier", 0.75) || 0.75
    BigDecimal(multiplier.to_s)
  end
end
