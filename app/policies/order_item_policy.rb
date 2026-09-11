class OrderItemPolicy < ApplicationPolicy
  def index?
    return false unless record.order
    OrderPolicy.new(user, record.order).show?
  end

  def show?
    return false unless record.order
    OrderPolicy.new(user, record.order).show?
  end

  def create?
    return false unless record.order
    OrderPolicy.new(user, record.order).create?
  end

  def update?
    return false unless record.order
    OrderPolicy.new(user, record.order).update?
  end

  def destroy?
    return false unless record.order
    OrderPolicy.new(user, record.order).destroy?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      order_scope = Pundit.policy_scope!(user, Order)
      scope.joins(:order).where(orders: { id: order_scope.select(:id) })
    end
  end
end
