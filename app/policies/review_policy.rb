class ReviewPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    customer? || admin?
  end

  def destroy?
    admin? || record.user_id == user&.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
