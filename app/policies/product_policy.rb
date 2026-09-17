class ProductPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.role&.name == "CUSTOMER" || user&.role&.name == "AFFILIATE"
        scope.where(active: true)
      else
        scope.all
      end
    end
  end
end
