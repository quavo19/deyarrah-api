module Api
  module V1
    module Orders
      class OrdersController < BaseController
        before_action :authenticate_user!
        before_action :set_order, only: [ :show, :update, :destroy, :cancel ]

        def index
          authorize Order
          @orders = policy_scope(Order)
            .includes(order_items: :variant_stock)
            .order(created_at: :desc)

          render json: {
            data: @orders.map do |order|
              {
                id: order.id,
                type: "order",
                attributes: {
                  user_id: order.user_id,
                  order_id: order.order_id,
                  status: order.status,
                  payment_status: order.payment_status,
                  delivery_distance: order.delivery_distance.to_f,
                  delivery_fee: order.delivery_fee.to_f,
                  item_subtotal: order.item_subtotal.to_f,
                  total_amount: order.total_amount.to_f,
                  total_price: order.total_price.to_s,
                  created_at: order.created_at.iso8601,
                  updated_at: order.updated_at.iso8601
                },
                relationships: {
                  order_items: {
                    data: order.order_items.map do |item|
                      {
                        id: item.id,
                        type: "order_item",
                        attributes: {
                          variant_stock_id: item.variant_stock_id,
                          quantity: item.quantity,
                          price: item.price.to_s
                        }
                      }
                    end
                  },
                  fulfillments: {
                    data: order.fulfillments.map do |fulfillment|
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
          authorize Order

          # Handle double-nested parameters (client sending {"order"=>{"order"=>{...}}})
          order_params_raw = params.require(:order)
          if order_params_raw.is_a?(ActionController::Parameters) && order_params_raw[:order].present?
            order_params_raw = order_params_raw[:order]
          end

          order_params_data = order_params_raw.permit(
            :warehouse_id,
            :customer_address_id,
            phones: [],
            order_items: [ :variant_stock_id, :quantity ],
            fulfillments: [ :warehouse_id, :delivery_date, :delivery_fee, order_items: [ :variant_stock_id, :quantity ] ],
            address: [ :name, :latitude, :longitude ]
          )

          # Handle customer_address_id: if provided, extract address data from it
          if order_params_raw[:customer_address_id].present?
            customer_address = current_user.customer_addresses.find_by(id: order_params_raw[:customer_address_id])
            unless customer_address
              render json: { error: "Address not found" }, status: :not_found
              return
            end
            # Populate address data from customer_address
            order_params_data[:address] = {
              name: customer_address.name,
              latitude: customer_address.latitude,
              longitude: customer_address.longitude
            }
          end

          # Convert order_items to hash format with symbol keys
          order_items_params = (order_params_data[:order_items] || []).map do |item|
            {
              variant_stock_id: item[:variant_stock_id] || item["variant_stock_id"],
              quantity: (item[:quantity] || item["quantity"]).to_i
            }
          end

          # Convert fulfillments_params to hash format with symbol keys
          fulfillments_params = (order_params_data[:fulfillments] || []).map do |fulfillment|
            {
              warehouse_id: fulfillment[:warehouse_id] || fulfillment["warehouse_id"],
              delivery_date: fulfillment[:delivery_date] || fulfillment["delivery_date"],
              delivery_fee: fulfillment[:delivery_fee] || fulfillment["delivery_fee"],
              order_items: (fulfillment[:order_items] || fulfillment["order_items"] || []).map do |item|
                {
                  variant_stock_id: item[:variant_stock_id] || item["variant_stock_id"],
                  quantity: (item[:quantity] || item["quantity"]).to_i
                }
              end
            }
          end

          # If fulfillments are not provided but warehouse_id is (backward compatibility), create a single fulfillment
          if fulfillments_params.empty? && order_params_data[:warehouse_id].present?
            fulfillments_params = [ {
              warehouse_id: order_params_data[:warehouse_id],
              order_items: order_items_params
            } ]
          end

          # Extract address data from params
          address_data = nil
          if order_params_data[:address].present?
            address_params = order_params_data[:address]
            address_data = {
              name: address_params[:name] || address_params["name"] || "Delivery Address",
              latitude: address_params[:latitude] || address_params["latitude"],
              longitude: address_params[:longitude] || address_params["longitude"]
            }
          end

          service = OrderService.new(
            current_user,
            order_items_params,
            fulfillments_params,
            address_data,
            (order_params_data[:phones] || [])
          )

          order = service.create
          authorize order

          render json: {
            data: {
              id: order.id,
              type: "order",
              attributes: {
                user_id: order.user_id,
                  order_id: order.order_id,
                status: order.status,
                payment_status: order.payment_status,
                delivery_distance: order.delivery_distance.to_f,
                delivery_fee: order.delivery_fee.to_f,
                item_subtotal: order.item_subtotal.to_f,
                total_amount: order.total_amount.to_f,
                total_price: order.total_price.to_s,
                created_at: order.created_at.iso8601,
                updated_at: order.updated_at.iso8601
              },
              relationships: {
                order_items: {
                  data: order.order_items.map do |item|
                    {
                      id: item.id,
                      type: "order_item",
                      attributes: {
                        variant_stock_id: item.variant_stock_id,
                        quantity: item.quantity,
                        price: item.price.to_s
                      }
                    }
                  end
                },
                fulfillments: {
                  data: order.fulfillments.map do |fulfillment|
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
        rescue OrderService::ValidationError => e
          render json: { error: e.message }, status: :unprocessable_entity
        rescue OrderService::AvailabilityConflictError => e
          render json: { error: e.message }, status: :conflict
        rescue OrderService::DowntimeConflictError => e
          render json: { error: e.message }, status: :conflict
        rescue OrderService::RedisUnavailableError => e
          render json: { error: "Service temporarily unavailable" }, status: :service_unavailable
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "Resource not found" }, status: :not_found
        end

        def show
          authorize @order

          render json: {
            data: {
              id: @order.id,
              type: "order",
              attributes: {
                user_id: @order.user_id,
                order_id: @order.order_id,
                status: @order.status,
                payment_status: @order.payment_status,
                delivery_distance: @order.delivery_distance.to_f,
                delivery_fee: @order.delivery_fee.to_f,
                item_subtotal: @order.item_subtotal.to_f,
                total_amount: @order.total_amount.to_f,
                total_price: @order.total_price.to_s,
                created_at: @order.created_at.iso8601,
                updated_at: @order.updated_at.iso8601
              },
              relationships: {
                order_items: {
                  data: @order.order_items.map do |item|
                    {
                      id: item.id,
                      type: "order_item",
                      attributes: {
                        variant_stock_id: item.variant_stock_id,
                        quantity: item.quantity,
                        price: item.price.to_s
                      }
                    }
                  end
                },
                fulfillments: {
                  data: @order.fulfillments.map do |fulfillment|
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
          authorize @order

          if @order.cancelled?
            render json: { error: "Cannot update cancelled order" }, status: :unprocessable_entity
            return
          end

          old_order_items = @order.order_items.to_a

          order_params_data = params.require(:order).permit(order_items: [ :variant_stock_id, :quantity ])
          order_items_params = order_params_data[:order_items] if order_params_data[:order_items].present?

          restorations = old_order_items.map do |item|
            {
              variant_stock_id: item.variant_stock_id,
              quantity: item.quantity
            }
          end

          locks = []
          begin
            all_variant_stock_ids = (old_order_items.map(&:variant_stock_id) + (order_items_params&.map { |p| p[:variant_stock_id] } || [])).uniq

            all_variant_stock_ids.each do |variant_stock_id|
              lock_value = AvailabilityStore.lock(variant_stock_id)
              locks << { variant_stock_id: variant_stock_id, lock_value: lock_value }
            end

            AvailabilityStore.atomic_multi_restore(restorations) if restorations.any?

            if order_items_params.present?
              variant_stock_ids = order_items_params.map { |item| item[:variant_stock_id] }.uniq
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

              reservations = order_items_params.map do |item_params|
                {
                  variant_stock_id: item_params[:variant_stock_id],
                  quantity: item_params[:quantity].to_i
                }
              end

              AvailabilityStore.atomic_multi_reserve(reservations)
            end

            ActiveRecord::Base.transaction do
              if order_items_params.present?
                @order.order_items.destroy_all
                order_items_params.each do |item_params|
                  @order.order_items.create!(
                    variant_stock_id: item_params[:variant_stock_id],
                    quantity: item_params[:quantity]
                  )
                end
              end

              @order.reload
            end

            render json: {
              data: {
                id: @order.id,
                type: "order",
                attributes: {
                  user_id: @order.user_id,
                  order_id: @order.order_id,
                  status: @order.status,
                  delivery_distance: @order.delivery_distance.to_f,
                  delivery_fee: @order.delivery_fee.to_f,
                  item_subtotal: @order.item_subtotal.to_f,
                  total_amount: @order.total_amount.to_f,
                  total_price: @order.total_price.to_s,
                  created_at: @order.created_at.iso8601,
                  updated_at: @order.updated_at.iso8601
                },
                relationships: {
                  order_items: {
                    data: @order.order_items.map do |item|
                      {
                        id: item.id,
                        type: "order_item",
                        attributes: {
                          variant_stock_id: item.variant_stock_id,
                          quantity: item.quantity,
                          price: item.price.to_s
                        }
                      }
                    end
                  },
                  fulfillments: {
                    data: @order.fulfillments.map do |fulfillment|
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
              errors: @order.errors.full_messages
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
        end

        def destroy
          authorize @order, :cancel?

          service = OrderCancellationService.new(@order)
          order = service.cancel

          render json: {
            data: {
              id: order.id,
              type: "order",
              attributes: {
                user_id: order.user_id,
                  order_id: order.order_id,
                status: order.status,
                delivery_distance: order.delivery_distance.to_f,
                delivery_fee: order.delivery_fee.to_f,
                item_subtotal: order.item_subtotal.to_f,
                total_amount: order.total_amount.to_f,
                total_price: order.total_price.to_s,
                created_at: order.created_at.iso8601,
                updated_at: order.updated_at.iso8601
              },
              relationships: {
                order_items: {
                  data: order.order_items.map do |item|
                    {
                      id: item.id,
                      type: "order_item",
                      attributes: {
                        variant_stock_id: item.variant_stock_id,
                        quantity: item.quantity,
                        price: item.price.to_s
                      }
                    }
                  end
                },
                fulfillments: {
                  data: order.fulfillments.map do |fulfillment|
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
        rescue OrderCancellationService::ValidationError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        def cancel
          authorize @order, :cancel?

          service = OrderCancellationService.new(@order)
          order = service.cancel

          render json: {
            data: {
              id: order.id,
              type: "order",
              attributes: {
                user_id: order.user_id,
                  order_id: order.order_id,
                status: order.status,
                delivery_distance: order.delivery_distance.to_f,
                delivery_fee: order.delivery_fee.to_f,
                item_subtotal: order.item_subtotal.to_f,
                total_amount: order.total_amount.to_f,
                total_price: order.total_price.to_s,
                created_at: order.created_at.iso8601,
                updated_at: order.updated_at.iso8601
              },
              relationships: {
                order_items: {
                  data: order.order_items.map do |item|
                    {
                      id: item.id,
                      type: "order_item",
                      attributes: {
                        variant_stock_id: item.variant_stock_id,
                        quantity: item.quantity,
                        price: item.price.to_s
                      }
                    }
                  end
                },
                fulfillments: {
                  data: order.fulfillments.map do |fulfillment|
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
        rescue OrderCancellationService::ValidationError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        private

        def set_order
          @order = policy_scope(Order)
            .includes(order_items: :variant_stock)
            .where("orders.id::text = :id OR orders.order_id = :order_id", id: params[:id], order_id: params[:id].to_s.upcase)
            .first
          unless @order
            render json: { error: "Order not found" }, status: :not_found
            nil
          end
        end

        def order_params
          params.require(:order).permit(order_items: [ :variant_stock_id, :quantity ])
        end
      end
    end
  end
end
