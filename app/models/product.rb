class Product < ApplicationRecord
  enum :bookable_type, { bulk: "bulk", unit: "unit" }
  enum :status, { available: "available", partial: "partial" }

  belongs_to :category, optional: true
  has_many :product_categories, dependent: :destroy
  has_many :categories, through: :product_categories
  has_many :product_sub_categories, dependent: :destroy
  has_many :sub_categories, through: :product_sub_categories
  has_many :product_meta, class_name: "ProductMeta", dependent: :destroy
  has_many :variant_types, dependent: :destroy
  has_many :variant_options, through: :variant_types
  has_many :variant_stocks, dependent: :destroy
  has_many :images, as: :owner, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :cart_items, dependent: :destroy
  has_many :cart_users, through: :cart_items, source: :user
  has_many :wishlist_items, dependent: :destroy
  has_many :wishlist_users, through: :wishlist_items, source: :user

  before_destroy :destroy_related_variant_stocks
  after_save :update_status_if_needed

  validates :name, presence: true
  validates :bookable_type, presence: true
  validates :bonus_points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def calculate_status
    has_active_downtime = variant_stocks.any? do |variant_stock|
      variant_stock.downtime_active?
    end

    has_active_downtime ? :partial : :available
  end

  def update_status
    new_status = calculate_status
    update_column(:status, new_status) if status != new_status.to_s
  end

  def base_price
    base_variant_type = variant_types.base.first
    return BigDecimal("0") unless base_variant_type

    base_variant_type.variant_options.minimum(:price) || BigDecimal("0")
  end

  private

  def update_status_if_needed
    # Only update status if variant_stocks changed or product was just created
    return unless saved_change_to_id? || saved_change_to_active?

    update_status
  end

  def destroy_related_variant_stocks
    variant_stock_ids = variant_stocks.pluck(:id)

    Downtime.where(variant_stock_id: variant_stock_ids).find_each do |downtime|
      if downtime.active?
        AvailabilityStore.toggle_downtime_off(downtime.variant_stock_id)
      end

      service = DowntimeService.new(downtime)
      Sidekiq::ScheduledSet.new.select do |job|
        service.matches_downtime_job?(job, downtime.id)
      end.each(&:delete)
    end

    # Nullify order_items instead of destroying them to preserve order data
    variant_stocks.each do |variant_stock|
      variant_stock.order_items.update_all(variant_stock_id: nil)
    end

    variant_stocks.destroy_all
  end
end
