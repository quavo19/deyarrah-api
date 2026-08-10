class Image < ApplicationRecord
  belongs_to :owner, polymorphic: true

  validates :url, presence: true
end
