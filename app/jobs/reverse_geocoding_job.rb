class ReverseGeocodingJob < ApplicationJob
  sidekiq_options queue: :default, retry: 3

  def perform(warehouse_id)
    warehouse = Warehouse.find_by(id: warehouse_id)
    return unless warehouse

    ReverseGeocodingService.new(warehouse).perform
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn("Warehouse #{warehouse_id} not found for reverse geocoding")
  rescue StandardError => e
    Rails.logger.error("Reverse geocoding job failed for warehouse #{warehouse_id}: #{e.message}")
    raise # Re-raise to trigger Sidekiq retry
  end
end
