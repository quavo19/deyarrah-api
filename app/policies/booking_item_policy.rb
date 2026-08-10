class BookingItemPolicy < ApplicationPolicy
  def index?
    return false unless record.booking
    BookingPolicy.new(user, record.booking).show?
  end

  def show?
    return false unless record.booking
    BookingPolicy.new(user, record.booking).show?
  end

  def create?
    return false unless record.booking
    BookingPolicy.new(user, record.booking).create?
  end

  def update?
    return false unless record.booking
    BookingPolicy.new(user, record.booking).update?
  end

  def destroy?
    return false unless record.booking
    BookingPolicy.new(user, record.booking).destroy?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      booking_scope = Pundit.policy_scope!(user, Booking)
      scope.joins(:booking).where(bookings: { id: booking_scope.select(:id) })
    end
  end
end
