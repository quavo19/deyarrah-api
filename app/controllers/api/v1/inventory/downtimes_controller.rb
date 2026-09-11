module Api
  module V1
    module Inventory
      class DowntimesController < BaseController
        before_action :authenticate_user!
        before_action :set_variant_stock, only: [ :index ]
        before_action :set_variant_stock_for_create, only: [ :create ]
        before_action :set_downtime, only: [ :show, :update, :destroy, :end_early ]

        def index
          authorize Downtime

          @downtimes = policy_scope(Downtime).includes(
            variant_stock: [
              { product: :images }
            ]
          )

          if @variant_stock
            @downtimes = @downtimes.for_variant_stock(@variant_stock.id)
          end

          if params[:start_at].present? && params[:end_at].present?
            start_at = Time.parse(params[:start_at])
            end_at = Time.parse(params[:end_at])
            @downtimes = @downtimes.in_range(start_at, end_at)
          end

          @downtimes = @downtimes.order(:start_at)

          # Collect all option_ids from all variant stocks to preload variant options
          all_option_ids = @downtimes.flat_map do |downtime|
            downtime.variant_stock&.option_ids || []
          end.uniq

          # Preload variant options with images and variant_type
          variant_options_by_id = if all_option_ids.any?
            VariantOption.where(id: all_option_ids).includes(:images, :variant_type).index_by(&:id)
          else
            {}
          end

          render json: {
            data: @downtimes.map do |downtime|
              variant_stock = downtime.variant_stock
              product = variant_stock&.product
              
              # Get variant options from preloaded hash
              variant_options = if variant_stock && variant_stock.option_ids.any?
                variant_stock.option_ids.map { |id| variant_options_by_id[id] }.compact
              else
                []
              end
              
              # Get product images (already loaded via includes)
              product_images = product ? product.images.order(created_at: :desc).map { |img| { id: img.id, url: img.url } } : []
              
              # Get variant option images (already loaded via includes)
              variant_option_images = variant_options.flat_map do |option|
                option.images.order(created_at: :desc).map { |img| { id: img.id, url: img.url, variant_option_id: option.id, variant_option_name: option.name } }
              end
              
              # Combine images: prefer variant option images if available, otherwise use product images
              images = variant_option_images.any? ? variant_option_images : product_images

              {
                id: downtime.id,
                type: "downtime",
                attributes: {
                  variant_stock_id: downtime.variant_stock_id,
                  warehouse_name: variant_stock.warehouse.name,
                  start_at: downtime.start_at.iso8601,
                  end_at: downtime.end_at.iso8601,
                  ended_at: downtime.ended_at&.iso8601,
                  reason: downtime.reason,
                  product: product ? {
                    id: product.id,
                    name: product.name,
                    description: get_variant_stock_names(variant_stock, variant_options),
                    bookable_type: product.bookable_type,
                    active: product.active
                  } : nil,
                  images: images,
                  created_at: downtime.created_at.iso8601,
                  updated_at: downtime.updated_at.iso8601
                }
              }
            end
          }, status: :ok
        rescue ArgumentError => e
          render json: { error: "Invalid date format" }, status: :unprocessable_entity
        end

        def create
          authorize Downtime
          return unless @variant_stock

          downtime_params_data = params.require(:downtime).permit(:variant_stock_id, :start_at, :end_at, :reason)
          
          variant_stock = @variant_stock
          start_at = Time.parse(downtime_params_data[:start_at])
          end_at = Time.parse(downtime_params_data[:end_at])
          reason = downtime_params_data[:reason]

          service = DowntimeService.new
          downtime = service.create(variant_stock, start_at, end_at, reason)
          authorize downtime

          render json: {
            data: {
              id: downtime.id,
              type: "downtime",
              attributes: {
                variant_stock_id: downtime.variant_stock_id,
                start_at: downtime.start_at.iso8601,
                end_at: downtime.end_at.iso8601,
                ended_at: downtime.ended_at&.iso8601,
                reason: downtime.reason,
                created_at: downtime.created_at.iso8601,
                updated_at: downtime.updated_at.iso8601
              }
            }
          }, status: :created
        rescue DowntimeService::ValidationError => e
          render json: { error: e.message }, status: :unprocessable_entity
        rescue DowntimeService::DowntimeConflictError => e
          render json: { error: e.message }, status: :conflict
        rescue DowntimeService::OrderConflictError => e
          render json: { error: e.message }, status: :conflict
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "Variant stock not found" }, status: :not_found
        rescue ArgumentError => e
          render json: { error: "Invalid date format" }, status: :unprocessable_entity
        end

        def show
          authorize @downtime

          render json: {
            data: {
              id: @downtime.id,
              type: "downtime",
              attributes: {
                variant_stock_id: @downtime.variant_stock_id,
                start_at: @downtime.start_at.iso8601,
                end_at: @downtime.end_at.iso8601,
                ended_at: @downtime.ended_at&.iso8601,
                reason: @downtime.reason,
                created_at: @downtime.created_at.iso8601,
                updated_at: @downtime.updated_at.iso8601
              }
            }
          }, status: :ok
        end

        def update
          authorize @downtime

          downtime_params_data = params.require(:downtime).permit(:start_at, :end_at, :reason)
          
          start_at = downtime_params_data[:start_at] ? Time.parse(downtime_params_data[:start_at]) : nil
          end_at = downtime_params_data[:end_at] ? Time.parse(downtime_params_data[:end_at]) : nil
          reason = downtime_params_data[:reason]

          service = DowntimeService.new(@downtime)
          downtime = service.update(start_at: start_at, end_at: end_at, reason: reason)

          render json: {
            data: {
              id: downtime.id,
              type: "downtime",
              attributes: {
                variant_stock_id: downtime.variant_stock_id,
                start_at: downtime.start_at.iso8601,
                end_at: downtime.end_at.iso8601,
                ended_at: downtime.ended_at&.iso8601,
                reason: downtime.reason,
                created_at: downtime.created_at.iso8601,
                updated_at: downtime.updated_at.iso8601
              }
            }
          }, status: :ok
        rescue DowntimeService::ValidationError => e
          render json: { error: e.message }, status: :unprocessable_entity
        rescue DowntimeService::DowntimeConflictError => e
          render json: { error: e.message }, status: :conflict
        rescue DowntimeService::OrderConflictError => e
          render json: { error: e.message }, status: :conflict
        rescue ArgumentError => e
          render json: { error: "Invalid date format" }, status: :unprocessable_entity
        end

        def destroy
          authorize @downtime

          was_active = @downtime.active?

          ActiveRecord::Base.transaction do
            if @downtime.destroy
              if was_active
                AvailabilityStore.toggle_downtime_off(@downtime.variant_stock_id)
              end

              # Cancel scheduled jobs for this downtime
              service = DowntimeService.new(@downtime)
              Sidekiq::ScheduledSet.new.select do |job|
                service.matches_downtime_job?(job, @downtime.id)
              end.each(&:delete)

              render json: {
                data: {
                  id: @downtime.id,
                  type: "downtime",
                  attributes: {
                    variant_stock_id: @downtime.variant_stock_id,
                    start_at: @downtime.start_at.iso8601,
                    end_at: @downtime.end_at.iso8601,
                    ended_at: @downtime.ended_at&.iso8601,
                    reason: @downtime.reason,
                    created_at: @downtime.created_at.iso8601,
                    updated_at: @downtime.updated_at.iso8601
                  }
                }
              }, status: :ok
            else
              render json: {
                error: "Failed to delete downtime",
                errors: @downtime.errors.full_messages
              }, status: :unprocessable_entity
            end
          end
        end

        def end_early
          authorize @downtime, :end_downtime?

          service = DowntimeService.new(@downtime)
          downtime = service.end_early

          render json: {
            message: "Downtime ended successfully",
            data: {
              id: downtime.id,
              type: "downtime",
              attributes: {
                variant_stock_id: downtime.variant_stock_id,
                start_at: downtime.start_at.iso8601,
                end_at: downtime.end_at.iso8601,
                ended_at: downtime.ended_at&.iso8601,
                reason: downtime.reason,
                created_at: downtime.created_at.iso8601,
                updated_at: downtime.updated_at.iso8601
              }
            }
          }, status: :ok
        rescue DowntimeService::ValidationError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        private

        def set_variant_stock
          @variant_stock = VariantStock.find(params[:variant_stock_id]) if params[:variant_stock_id].present?
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "Variant stock not found" }, status: :not_found
          nil
        end

        def set_variant_stock_for_create
          variant_stock_id = params[:downtime]&.dig(:variant_stock_id) || params[:variant_stock_id]
          @variant_stock = VariantStock.find(variant_stock_id) if variant_stock_id.present?
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "Variant stock not found" }, status: :not_found
          nil
        end

        def set_downtime
          @downtime = policy_scope(Downtime).find_by(id: params[:id])
          unless @downtime
            render json: { error: "Downtime not found" }, status: :not_found
            nil
          end
        end

        def downtime_params
          params.require(:downtime).permit(:variant_stock_id, :start_at, :end_at, :reason)
        end

        def get_variant_stock_names(variant_stock, variant_options)
          return "" unless variant_stock
          
          if variant_options.empty? || variant_options.nil?
            return ""
          end
          
          variant_options_by_type = variant_options.group_by { |opt| opt.variant_type_id }
          
          variant_options_by_type.map do |variant_type_id, options|
            variant_type = options.first.variant_type
            option_names = options.map(&:name).join(", ")
            " #{option_names}"
          end.join(" / ")
        end
      end
    end
  end
end
