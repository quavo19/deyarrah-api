class BadgePolicy < ApplicationPolicy
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

  def add_user?
    admin?
  end

  def remove_user?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      admin? ? scope.all : scope.none
    end

    private

    def admin?
      user&.role&.name == "ADMIN" || user&.role&.name == "SUPER_ADMIN"
    end
  end
end
