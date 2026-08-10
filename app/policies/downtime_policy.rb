class DowntimePolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    admin?
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

  def end_downtime?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.role&.name == "ADMIN" || user&.role&.name == "SUPER_ADMIN"
        scope.all
      else
        scope.none
      end
    end
  end
end
