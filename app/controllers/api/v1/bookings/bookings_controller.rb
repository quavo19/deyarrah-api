module Api
  module V1
    module Bookings
      class BookingsController < BaseController
        before_action :authenticate_user!
        before_action :set_booking, only: [ :show, :update, :destroy, :cancel ]

        def index
          authorize Booking
          @bookings = policy_scope(Booking)
            .includes(booking_items: :variant_stock)
            .order(created_at: :desc)

          render json: {
            data: @bookings.map do |booking|
              {
                id: booking.id,
                type: "booking",
                attributes: {
                  user_id: booking.user_id,
                  product_id: booking.product_id,
                  start_at: booking.start_at.iso8601,
                  end_at: booking.end_at.iso8601,
                  status: booking.status,
                  payment_status: booking.payment_status,
                  delivery_distance: booking.delivery_distance.to_f,
                  delivery_fee: booking.delivery_fee.to_f,
                  item_subtotal: booking.item_subtotal.to_f,
                  total_amount: booking.total_amount.to_f,
                  total_price: booking.total_price.to_s,
                  created_at: booking.created_at.iso8601,
                  updated_at: booking.updated_at.iso8601
                },
                relationships: {
                  booking_items: {
                    data: booking.booking_items.map do |item|
                      {
                        id: item.id,
                        type: "booking_item",
                        attributes: {
                          variant_stock_id: item.variant_stock_id,
                          quantity: item.quantity,
                          price: item.price.to_s
                        }
                      }
                    end
                  },
                  fulfillments: {
                    data: booking.fulfillments.map do |fulfillment|
                      {
                        id: fulfillment.id,
                        type: "fulfillment",
                        attributes: {
                          warehouse_id: fulfillment.warehouse_id,
                          status: fulfillment.status,
                          delivery_date: fulfillment.delivery_date&.iso8601,
                          delivery_fee: fulfillment.delivery_fee
                        }
                      }
                    end
                  }
                }
              }
            end
          }, status: :ok
        end

        def create
          authorize Booking

          # Handle double-nested parameters (client sending {"booking"=>{"booking"=>{...}}})
          booking_params_raw = params.require(:booking)
          if booking_params_raw.is_a?(ActionController::Parameters) && booking_params_raw[:booking].present?
            booking_params_raw = booking_params_raw[:booking]
          end

          booking_params_data = booking_params_raw.permit(
            :product_id,
            :warehouse_id,
            :customer_address_id,
            :start_at,
            :end_at,
            phones: [],
            booking_items: [ :variant_stock_id, :quantity ],
            fulfillments: [ :warehouse_id, :delivery_date, :delivery_fee, booking_items: [ :variant_stock_id, :quantity ] ],
            address: [ :name, :latitude, :longitude ]
          )

          # Handle customer_address_id: if provided, extract address data from it
          if booking_params_raw[:customer_address_id].present?
            customer_address = current_user.customer_addresses.find_by(id: booking_params_raw[:customer_address_id])
            unless customer_address
              render json: { error: "Address not found" }, status: :not_found
              return
            end
            # Populate address data from customer_address
            booking_params_data[:address] = {
              name: customer_address.name,
              latitude: customer_address.latitude,
              longitude: customer_address.longitude
            }
          end

          product = Product.find(booking_params_data[:product_id])
          authorize product, :show?

          start_at = Time.parse(booking_params_data[:start_at])
          end_at = Time.parse(booking_params_data[:end_at])

          # Convert booking_items to hash format with symbol keys
          booking_items_params = (booking_params_data[:booking_items] || []).map do |item|
            {
              variant_stock_id: item[:variant_stock_id] || item["variant_stock_id"],
              quantity: (item[:quantity] || item["quantity"]).to_i
            }
          end

          # Convert fulfillments_params to hash format with symbol keys
          fulfillments_params = (booking_params_data[:fulfillments] || []).map do |fulfillment|
            {
              warehouse_id: fulfillment[:warehouse_id] || fulfillment["warehouse_id"],
              delivery_date: fulfillment[:delivery_date] || fulfillment["delivery_date"],
              delivery_fee: fulfillment[:delivery_fee] || fulfillment["delivery_fee"],
              booking_items: (fulfillment[:booking_items] || fulfillment["booking_items"] || []).map do |item|
                {
                  variant_stock_id: item[:variant_stock_id] || item["variant_stock_id"],
                  quantity: (item[:quantity] || item["quantity"]).to_i
                }
              end
            }
          end

          # If fulfillments are not provided but warehouse_id is (backward compatibility), create a single fulfillment
          if fulfillments_params.empty? && booking_params_data[:warehouse_id].present?
            fulfillments_params = [ {
              warehouse_id: booking_params_data[:warehouse_id],
              booking_items: booking_items_params
            } ]
          end

          # Extract address data from params
          address_data = nil
          if booking_params_data[:address].present?
            address_params = booking_params_data[:address]
            address_data = {
              name: address_params[:name] || address_params["name"] || "Delivery Address",
              latitude: address_params[:latitude] || address_params["latitude"],
              longitude: address_params[:longitude] || address_params["longitude"]
            }
          end

          service = BookingService.new(
            current_user,
            product,
            start_at,
            end_at,
            booking_items_params,
            fulfillments_params,
            address_data,
            (booking_params_data[:phones] || [])
          )

          booking = service.create
          authorize booking

          render json: {
            data: {
              id: booking.id,
              type: "booking",
              attributes: {
                user_id: booking.user_id,
                product_id: booking.product_id,
                start_at: booking.start_at.iso8601,
                end_at: booking.end_at.iso8601,
                status: booking.status,
                payment_status: booking.payment_status,
                delivery_distance: booking.delivery_distance.to_f,
                delivery_fee: booking.delivery_fee.to_f,
                item_subtotal: booking.item_subtotal.to_f,
                total_amount: booking.total_amount.to_f,
                total_price: booking.total_price.to_s,
                created_at: booking.created_at.iso8601,
                updated_at: booking.updated_at.iso8601
              },
              relationships: {
                booking_items: {
                  data: booking.booking_items.map do |item|
                    {
                      id: item.id,
                      type: "booking_item",
                      attributes: {
                        variant_stock_id: item.variant_stock_id,
                        quantity: item.quantity,
                        price: item.price.to_s
                      }
                    }
                  end
                },
                fulfillments: {
                  data: booking.fulfillments.map do |fulfillment|
                    {
                      id: fulfillment.id,
                      type: "fulfillment",
                      attributes: {
                        warehouse_id: fulfillment.warehouse_id,
                        status: fulfillment.status,
                        delivery_date: fulfillment.delivery_date&.iso8601,
                        delivery_fee: fulfillment.delivery_fee
                      }
                    }
                  end
                }
              }
            }
          }, status: :created
        rescue BookingService::ValidationError => e
          render json: { error: e.message }, status: :unprocessable_entity
        rescue BookingService::TimeRangeInvalidError => e
          render json: { error: e.message }, status: :unprocessable_entity
        rescue BookingService::BookingOverlapError => e
          render json: { error: e.message }, status: :conflict
        rescue BookingService::AvailabilityConflictError => e
          render json: { error: e.message }, status: :conflict
        rescue BookingService::DowntimeConflictError => e
          render json: { error: e.message }, status: :conflict
        rescue BookingService::RedisUnavailableError => e
          render json: { error: "Service temporarily unavailable" }, status: :service_unavailable
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "Resource not found" }, status: :not_found
        rescue ArgumentError => e
          render json: { error: "Invalid date format" }, status: :unprocessable_entity
        end

        def show
          authorize @booking

          render json: {
            data: {
              id: @booking.id,
              type: "booking",
              attributes: {
                user_id: @booking.user_id,
                product_id: @booking.product_id,
                start_at: @booking.start_at.iso8601,
                end_at: @booking.end_at.iso8601,
                status: @booking.status,
                payment_status: @booking.payment_status,
                delivery_distance: @booking.delivery_distance.to_f,
                delivery_fee: @booking.delivery_fee.to_f,
                item_subtotal: @booking.item_subtotal.to_f,
                total_amount: @booking.total_amount.to_f,
                total_price: @booking.total_price.to_s,
                created_at: @booking.created_at.iso8601,
                updated_at: @booking.updated_at.iso8601
              },
              relationships: {
                booking_items: {
                  data: @booking.booking_items.map do |item|
                    {
                      id: item.id,
                      type: "booking_item",
                      attributes: {
                        variant_stock_id: item.variant_stock_id,
                        quantity: item.quantity,
                        price: item.price.to_s
                      }
                    }
                  end
                },
                fulfillments: {
                  data: @booking.fulfillments.map do |fulfillment|
                    {
                      id: fulfillment.id,
                      type: "fulfillment",
                      attributes: {
                        warehouse_id: fulfillment.warehouse_id,
                        status: fulfillment.status,
                        delivery_date: fulfillment.delivery_date&.iso8601,
                        delivery_fee: fulfillment.delivery_fee
                      }
                    }
                  end
                }
              }
            }
          }, status: :ok
        end

        def update
          authorize @booking

          if @booking.cancelled?
            render json: { error: "Cannot update cancelled booking" }, status: :unprocessable_entity
            return
          end

          old_booking_items = @booking.booking_items.to_a

          booking_params_data = params.require(:booking).permit(:start_at, :end_at, booking_items: [ :variant_stock_id, :quantity ])
          start_at = booking_params_data[:start_at] ? Time.parse(booking_params_data[:start_at]) : @booking.start_at
          end_at = booking_params_data[:end_at] ? Time.parse(booking_params_data[:end_at]) : @booking.end_at
          booking_items_params = booking_params_data[:booking_items] if booking_params_data[:booking_items].present?

          if end_at <= start_at
            render json: { error: "end_at must be after start_at" }, status: :unprocessable_entity
            return
          end

          restorations = old_booking_items.map do |item|
            {
              variant_stock_id: item.variant_stock_id,
              quantity: item.quantity
            }
          end

          locks = []
          begin
            all_variant_stock_ids = (old_booking_items.map(&:variant_stock_id) + (booking_items_params&.map { |p| p[:variant_stock_id] } || [])).uniq

            all_variant_stock_ids.each do |variant_stock_id|
              lock_value = AvailabilityStore.lock(variant_stock_id)
              locks << { variant_stock_id: variant_stock_id, lock_value: lock_value }
            end

            AvailabilityStore.atomic_multi_restore(restorations) if restorations.any?

            if booking_items_params.present?
              variant_stock_ids = booking_items_params.map { |item| item[:variant_stock_id] }.uniq
              variant_stocks = VariantStock.where(id: variant_stock_ids).index_by(&:id)

              variant_stock_ids.each do |variant_stock_id|
                variant_stock = variant_stocks[variant_stock_id]
                if variant_stock
                  total = AvailabilityStore.get_total_quantity(variant_stock_id)
                  if total.nil?
                    AvailabilityStore.initialize_from_db(variant_stock)
                  end
                end
              end

              reservations = booking_items_params.map do |item_params|
                {
                  variant_stock_id: item_params[:variant_stock_id],
                  quantity: item_params[:quantity].to_i
                }
              end

              AvailabilityStore.atomic_multi_reserve(reservations)
            end

            ActiveRecord::Base.transaction do
              @booking.update!(
                start_at: start_at,
                end_at: end_at
              )

              if booking_items_params.present?
                @booking.booking_items.destroy_all
                booking_items_params.each do |item_params|
                  @booking.booking_items.create!(
                    variant_stock_id: item_params[:variant_stock_id],
                    quantity: item_params[:quantity]
                  )
                end
              end

              @booking.reload
            end

            render json: {
              data: {
                id: @booking.id,
                type: "booking",
                attributes: {
                  user_id: @booking.user_id,
                  product_id: @booking.product_id,
                  start_at: @booking.start_at.iso8601,
                  end_at: @booking.end_at.iso8601,
                  status: @booking.status,
                  delivery_distance: @booking.delivery_distance.to_f,
                  delivery_fee: @booking.delivery_fee.to_f,
                  item_subtotal: @booking.item_subtotal.to_f,
                  total_amount: @booking.total_amount.to_f,
                  total_price: @booking.total_price.to_s,
                  created_at: @booking.created_at.iso8601,
                  updated_at: @booking.updated_at.iso8601
                },
                relationships: {
                  booking_items: {
                    data: @booking.booking_items.map do |item|
                      {
                        id: item.id,
                        type: "booking_item",
                        attributes: {
                          variant_stock_id: item.variant_stock_id,
                          quantity: item.quantity,
                          price: item.price.to_s
                        }
                      }
                    end
                  },
                  fulfillments: {
                    data: @booking.fulfillments.map do |fulfillment|
                      {
                        id: fulfillment.id,
                        type: "fulfillment",
                        attributes: {
                          warehouse_id: fulfillment.warehouse_id,
                          status: fulfillment.status,
                          delivery_date: fulfillment.delivery_date&.iso8601,
                          delivery_fee: fulfillment.delivery_fee
                        }
                      }
                    end
                  }
                }
              }
            }, status: :ok
          rescue AvailabilityStore::InsufficientAvailabilityError => e
            AvailabilityStore.atomic_multi_restore(restorations) if restorations.any?
            render json: { error: e.message }, status: :conflict
          rescue AvailabilityStore::DowntimeConflictError => e
            AvailabilityStore.atomic_multi_restore(restorations) if restorations.any?
            render json: { error: e.message }, status: :conflict
          rescue AvailabilityStore::AvailabilityError => e
            AvailabilityStore.atomic_multi_restore(restorations) if restorations.any?
            render json: { error: e.message }, status: :unprocessable_entity
          rescue AvailabilityStore::LockError => e
            AvailabilityStore.atomic_multi_restore(restorations) if restorations.any?
            render json: { error: "Concurrency conflict: #{e.message}" }, status: :conflict
          rescue ActiveRecord::RecordInvalid => e
            AvailabilityStore.atomic_multi_restore(restorations) if restorations.any?
            render json: {
              error: "Validation failed",
              errors: @booking.errors.full_messages
            }, status: :unprocessable_entity
          rescue StandardError => e
            AvailabilityStore.atomic_multi_restore(restorations) if restorations.any?
            raise
          ensure
            locks.each do |lock|
              begin
                AvailabilityStore.unlock(lock[:variant_stock_id], lock[:lock_value])
              rescue StandardError => e
                Rails.logger.error("Failed to release lock for variant_stock #{lock[:variant_stock_id]}: #{e.message}")
              end
            end
          end
        rescue ArgumentError => e
          render json: { error: "Invalid date format" }, status: :unprocessable_entity
        end

        def destroy
          authorize @booking, :cancel?

          service = BookingCancellationService.new(@booking)
          booking = service.cancel

          render json: {
            data: {
              id: booking.id,
              type: "booking",
              attributes: {
                user_id: booking.user_id,
                product_id: booking.product_id,
                start_at: booking.start_at.iso8601,
                end_at: booking.end_at.iso8601,
                status: booking.status,
                delivery_distance: booking.delivery_distance.to_f,
                delivery_fee: booking.delivery_fee.to_f,
                item_subtotal: booking.item_subtotal.to_f,
                total_amount: booking.total_amount.to_f,
                total_price: booking.total_price.to_s,
                created_at: booking.created_at.iso8601,
                updated_at: booking.updated_at.iso8601
              },
              relationships: {
                booking_items: {
                  data: booking.booking_items.map do |item|
                    {
                      id: item.id,
                      type: "booking_item",
                      attributes: {
                        variant_stock_id: item.variant_stock_id,
                        quantity: item.quantity,
                        price: item.price.to_s
                      }
                    }
                  end
                },
                fulfillments: {
                  data: booking.fulfillments.map do |fulfillment|
                    {
                      id: fulfillment.id,
                      type: "fulfillment",
                      attributes: {
                        warehouse_id: fulfillment.warehouse_id,
                        status: fulfillment.status,
                        delivery_date: fulfillment.delivery_date&.iso8601,
                        delivery_fee: fulfillment.delivery_fee
                      }
                    }
                  end
                }
              }
            }
          }, status: :ok
        rescue BookingCancellationService::ValidationError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        def cancel
          authorize @booking, :cancel?

          service = BookingCancellationService.new(@booking)
          booking = service.cancel

          render json: {
            data: {
              id: booking.id,
              type: "booking",
              attributes: {
                user_id: booking.user_id,
                product_id: booking.product_id,
                start_at: booking.start_at.iso8601,
                end_at: booking.end_at.iso8601,
                status: booking.status,
                delivery_distance: booking.delivery_distance.to_f,
                delivery_fee: booking.delivery_fee.to_f,
                item_subtotal: booking.item_subtotal.to_f,
                total_amount: booking.total_amount.to_f,
                total_price: booking.total_price.to_s,
                created_at: booking.created_at.iso8601,
                updated_at: booking.updated_at.iso8601
              },
              relationships: {
                booking_items: {
                  data: booking.booking_items.map do |item|
                    {
                      id: item.id,
                      type: "booking_item",
                      attributes: {
                        variant_stock_id: item.variant_stock_id,
                        quantity: item.quantity,
                        price: item.price.to_s
                      }
                    }
                  end
                },
                fulfillments: {
                  data: booking.fulfillments.map do |fulfillment|
                    {
                      id: fulfillment.id,
                      type: "fulfillment",
                      attributes: {
                        warehouse_id: fulfillment.warehouse_id,
                        status: fulfillment.status,
                        delivery_date: fulfillment.delivery_date&.iso8601,
                        delivery_fee: fulfillment.delivery_fee
                      }
                    }
                  end
                }
              }
            }
          }, status: :ok
        rescue BookingCancellationService::ValidationError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        private

        def set_booking
          @booking = policy_scope(Booking)
            .includes(booking_items: :variant_stock)
            .find_by(id: params[:id])
          unless @booking
            render json: { error: "Booking not found" }, status: :not_found
            nil
          end
        end

        def booking_params
          params.require(:booking).permit(:product_id, :start_at, :end_at, booking_items: [ :variant_stock_id, :quantity ])
        end
      end
    end
  end
end
