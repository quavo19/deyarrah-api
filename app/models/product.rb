class Product < ApplicationRecord
  enum :bookable_type, { bulk: "bulk", unit: "unit" }
  enum :status, { available: "available", partial: "partial" }

  belongs_to :category, optional: true
  has_many :product_meta, class_name: "ProductMeta", dependent: :destroy
  has_many :variant_types, dependent: :destroy
  has_many :variant_options, through: :variant_types
  has_many :variant_stocks, dependent: :destroy
  has_many :images, as: :owner, dependent: :destroy
  has_many :bookings, dependent: :nullify

  before_destroy :destroy_related_variant_stocks
  after_save :update_status_if_needed

  validates :name, presence: true
  validates :bookable_type, presence: true

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

    # Nullify booking_items instead of destroying them to preserve booking data
    variant_stocks.each do |variant_stock|
      variant_stock.booking_items.update_all(variant_stock_id: nil)
    end

    variant_stocks.destroy_all
  end
end
