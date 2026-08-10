class ContactMessagePolicy < ApplicationPolicy
  def index?
    admin?
  end

  def create?
    true
  end

  def destroy?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.role&.name == "ADMIN" || user&.role&.name == "SUPER_ADMIN"

      scope.none
    end
  end
end

