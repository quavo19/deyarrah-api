class Bonus < ApplicationRecord
  self.table_name = "bonuses"

  belongs_to :user

  validates :balance, numericality: { greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: true
end
