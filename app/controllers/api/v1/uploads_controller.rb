module Api
  module V1
    class UploadsController < BaseController
      before_action :authenticate_user!

      def create
        unless R2Storage.configured?
          render json: { error: "R2 not configured" }, status: :service_unavailable
          return
        end

        file = params[:file]

        unless file.respond_to?(:original_filename) && file.respond_to?(:tempfile)
          render json: { error: "file is required" }, status: :unprocessable_entity
          return
        end

        content_type = file.content_type.presence || "application/octet-stream"
        key = R2Storage.build_key(file.original_filename)

        file.tempfile.rewind
        R2Storage.put_object(key, body: file.tempfile, content_type: content_type)

        render json: {
          file: {
            key: key,
            url: R2Storage.public_url(key),
            filename: file.original_filename,
            content_type: content_type
          }
        }, status: :created
      rescue Aws::S3::Errors::ServiceError => e
        Rails.logger.warn "R2 upload failed: #{e.message}"
        render json: { error: "Image upload failed" }, status: :bad_gateway
      end

      def presign
        unless R2Storage.configured?
          render json: { error: "R2 not configured" }, status: :service_unavailable
          return
        end

        filename = params[:filename].to_s.strip
        content_type = params[:content_type].presence || "application/octet-stream"

        if filename.blank?
          render json: { error: "filename is required" }, status: :unprocessable_entity
          return
        end

        key = R2Storage.build_key(filename)

        render json: {
          url: R2Storage.presigned_put_url(key, content_type: content_type),
          key: key,
          public_url: R2Storage.public_url(key),
          expires_in: 300
        }, status: :ok
      end

      def confirm
        unless R2Storage.configured?
          render json: { error: "R2 not configured" }, status: :service_unavailable
          return
        end

        key = params[:key].to_s.strip

        if key.blank?
          render json: { error: "key is required" }, status: :unprocessable_entity
          return
        end

        unless R2Storage.exists?(key)
          render json: { error: "file not found" }, status: :not_found
          return
        end

        render json: {
          file: {
            key: key,
            url: R2Storage.public_url(key),
            filename: params[:filename],
            content_type: params[:content_type]
          }
        }, status: :ok
      end

      def destroy
        key = params[:key].to_s.strip
        R2Storage.delete!(key)

        render json: { status: "deleted", key: key }, status: :ok
      end
    end
  end
end
