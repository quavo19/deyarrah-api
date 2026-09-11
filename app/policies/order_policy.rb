class OrderPolicy < ApplicationPolicy
  def index?
    admin? || staff? || customer?
  end

  def show?
    admin? || owner? || assigned_staff?
  end

  def create?
    customer? || admin?
  end

  def update?
    admin? || (owner? && record.status != "cancelled") || (assigned_staff? && record.status != "cancelled")
  end

  def destroy?
    admin? || (owner? && record.status != "cancelled")
  end

  def cancel?
    admin? || (owner? && record.status != "cancelled")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.role&.name == "ADMIN" || user&.role&.name == "SUPER_ADMIN"
        scope.all
      elsif user&.role&.name == "STAFF"
        scope.all
      elsif user&.role&.name == "CUSTOMER"
        scope.where(user_id: user.id)
      else
        scope.none
      end
    end
  end

  private

  def owner?
    record.user_id == user.id
  end

  def assigned_staff?
    staff? && record.assigned_to_id == user.id
  end
end
