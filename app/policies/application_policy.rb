class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def cancel?
    false
  end

  def end_downtime?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end

  private

  def admin?
    user&.role&.name == "ADMIN" || user&.role&.name == "SUPER_ADMIN"
  end

  def staff?
    user&.role&.name == "STAFF"
  end

  def customer?
    user&.role&.name == "CUSTOMER"
  end
end
