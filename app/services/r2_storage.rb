class R2Storage
  UPLOAD_PREFIX = "uploads/".freeze

  REQUIRED_ENV = %w[
    R2_ACCOUNT_ID
    R2_ACCESS_KEY_ID
    R2_SECRET_ACCESS_KEY
    R2_BUCKET_NAME
    R2_PUBLIC_BASE_URL
  ].freeze

  class << self
    def configured?
      REQUIRED_ENV.all? { |key| ENV[key].present? } && defined?(R2_CLIENT) && defined?(R2_PRESIGNER)
    end

    def build_key(filename)
      clean = File.basename(filename.to_s).gsub(/[^0-9A-Za-z.\-_]/, "_")
      "#{UPLOAD_PREFIX}#{SecureRandom.uuid}/#{clean.presence || 'image'}"
    end

    def presigned_put_url(key, content_type:)
      R2_PRESIGNER.presigned_url(
        :put_object,
        bucket: ENV.fetch("R2_BUCKET_NAME"),
        key: key,
        content_type: content_type,
        expires_in: 300
      )
    end

    def public_url(key)
      "#{ENV.fetch('R2_PUBLIC_BASE_URL').to_s.chomp('/')}/#{key}"
    end

    def exists?(key)
      return false unless safe_key?(key)

      R2_CLIENT.head_object(bucket: ENV.fetch("R2_BUCKET_NAME"), key: key)
      true
    rescue Aws::S3::Errors::NotFound
      false
    end

    def delete!(key)
      return false unless configured?
      return false unless safe_key?(key)

      R2_CLIENT.delete_object(bucket: ENV.fetch("R2_BUCKET_NAME"), key: key)
      true
    end

    def key_from_public_url(url)
      base = ENV.fetch("R2_PUBLIC_BASE_URL", "").to_s.chomp("/")
      return nil if base.blank? || url.blank?

      prefix = "#{base}/"
      return nil unless url.to_s.start_with?(prefix)

      key = url.to_s.delete_prefix(prefix)
      safe_key?(key) ? key : nil
    end

    def safe_key?(key)
      key.present? && key.to_s.start_with?(UPLOAD_PREFIX) && !key.to_s.include?("..")
    end
  end
end
