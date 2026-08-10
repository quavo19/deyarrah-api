class ImagePolicy < ApplicationPolicy
  def index?
    parent_readable?
  end

  def show?
    parent_readable?
  end

  def create?
    parent_writable?
  end

  def update?
    parent_writable?
  end

  def destroy?
    parent_writable?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  private

  def parent_readable?
    return false unless record&.owner

    case record.owner_type
    when "Product"
      ProductPolicy.new(user, record.owner).show?
    when "VariantOption"
      VariantOptionPolicy.new(user, record.owner).show?
    when "Warehouse"
      WarehousePolicy.new(user, record.owner).show?
    else
      false
    end
  end

  def parent_writable?
    return false unless record&.owner

    case record.owner_type
    when "Product"
      ProductPolicy.new(user, record.owner).update?
    when "VariantOption"
      VariantOptionPolicy.new(user, record.owner).update?
    when "Warehouse"
      WarehousePolicy.new(user, record.owner).update?
    else
      false
    end
  end
end
