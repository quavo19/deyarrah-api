class Transaction < ApplicationRecord
  enum :status, {
    initialized: "initialized",
    pending: "pending",
    success: "success",
    failed: "failed"
  }

  belongs_to :order

  validates :amount_kobo, presence: true
  validates :currency, presence: true
  validates :provider, presence: true
  validates :provider_reference, presence: true, uniqueness: true
end

