class Image < ApplicationRecord
  belongs_to :owner, polymorphic: true

  validates :url, presence: true

  after_destroy_commit :delete_image_from_r2
  after_update_commit :delete_old_image_from_r2, if: :saved_change_to_storage_key?

  private

  def delete_image_from_r2
    R2Storage.delete!(storage_key)
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.warn "R2 delete failed for image #{id}: #{e.message}"
  end

  def delete_old_image_from_r2
    old_key, new_key = saved_change_to_storage_key
    return if old_key.blank? || old_key == new_key

    R2Storage.delete!(old_key)
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.warn "R2 old image delete failed for image #{id}: #{e.message}"
  end
end
