class Permission < ApplicationRecord
  has_many :user_permissions, dependent: :destroy
  has_many :users, through: :user_permissions

  validates :name, presence: true, uniqueness: true

  # Prevent deletion of seeded permissions
  before_destroy :prevent_deletion

  private

  def prevent_deletion
    errors.add(:base, "Cannot delete seeded permissions")
    throw :abort
  end
end
