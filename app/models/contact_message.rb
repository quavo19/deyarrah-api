class ContactMessage < ApplicationRecord
  validates :purpose, presence: true
  validates :message, presence: true
  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true
end

