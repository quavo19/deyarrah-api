class Downtime < ApplicationRecord
  belongs_to :variant_stock
  has_one :product, through: :variant_stock

  before_destroy :cleanup_downtime
  after_save :update_product_status
  after_destroy :update_product_status_after_destroy

  validates :start_at, presence: true
  validates :end_at, presence: true
  validate :end_after_start

  scope :active, ->(at_time = Time.current) {
    where("start_at <= ? AND end_at > ?", at_time, at_time)
      .where(ended_at: nil)
  }

  scope :overlapping, ->(start_at, end_at) {
    where("start_at < ? AND end_at > ?", end_at, start_at)
      .where(ended_at: nil)
  }

  scope :for_variant_stock, ->(variant_stock_id) {
    where(variant_stock_id: variant_stock_id)
  }

  scope :in_range, ->(start_at, end_at) {
    where("start_at < ? AND end_at > ?", end_at, start_at)
  }

  def active?(at_time = Time.current)
    start_at <= at_time && end_at > at_time && ended_at.nil?
  end

  def ended?
    ended_at.present? || end_at <= Time.current
  end

  def scheduled?(at_time = Time.current)
    start_at > at_time && ended_at.nil?
  end

  private

  def update_product_status
    return unless variant_stock&.product
    variant_stock.product.update_status
  end

  def update_product_status_after_destroy
    return unless variant_stock&.product
    variant_stock.product.update_status
  end

  def cleanup_downtime
    if active?
      AvailabilityStore.toggle_downtime_off(variant_stock_id)
    end

    service = DowntimeService.new(self)
    Sidekiq::ScheduledSet.new.select do |job|
      service.matches_downtime_job?(job, id)
    end.each(&:delete)
  end

  def end_after_start
    return unless start_at.present? && end_at.present?
    if end_at <= start_at
      errors.add(:end_at, "must be after start_at")
    end
  end
end
