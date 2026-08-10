class Role < ApplicationRecord
  has_many :users, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true

  # Prevent deletion of seeded roles
  before_destroy :prevent_deletion

  private

  def prevent_deletion
    errors.add(:base, "Cannot delete seeded roles")
    throw :abort
  end
end
