class AffiliateSetting < ApplicationRecord
  validates :signup_referral_percentage, numericality: { greater_than_or_equal_to: 0 }
  validates :signup_referral_cap_amount, numericality: { greater_than_or_equal_to: 0 }

  def self.current
    first_or_create!(
      signup_referral_percentage: 0,
      signup_referral_cap_amount: 0,
      signup_referral_enabled: true
    )
  end
end
