module Api
  module V1
    module Customer
      module Orders
        class OrdersController < BaseController
          before_action :authenticate_user!
          before_action :set_order, only: [ :show, :mark_received ]

          def index
            @orders = Order.where(user_id: current_user.id)
              .includes(
                order_items: :variant_stock,
                fulfillments: :warehouse
              )
              .order(created_at: :desc)

            # Filter by status if provided
            if params[:status].present?
              @orders = @orders.where(status: params[:status])
            end

            if params[:search].present?
              term = "%#{params[:search].to_s.upcase}%"
              @orders = @orders.where("orders.order_id ILIKE ?", term)
            end

            # Kaminari pagination
            page = params[:page] || 1
            per_page = params[:per_page] || 25
            @orders = @orders.page(page).per(per_page)

            render json: {
              data: @orders.map do |order|
                {
                  id: order.id,
                  type: "order",
                  attributes: {
                    status: order.status,
                order_id: order.order_id,
                    payment_status: order.payment_status,
                    delivery_distance: order.delivery_distance.to_f,
                    delivery_fee: order.delivery_fee.to_f,
                    item_subtotal: order.item_subtotal.to_f,
                    total_amount: order.total_amount.to_f,
                    total_price: order.total_price.to_f,
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
                            price: item.price.to_f
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
                            warehouse_name: fulfillment.warehouse&.name,
                            status: fulfillment.status,
                            delivery_date: fulfillment.delivery_date&.iso8601,
                            delivery_fee: fulfillment.delivery_fee&.to_f
                          }
                        }
                      end
                    }
                  }
                }
              end,
              meta: {
                current_page: @orders.current_page,
                per_page: @orders.limit_value,
                total_pages: @orders.total_pages,
                total_count: @orders.total_count
              }
            }, status: :ok
          rescue ArgumentError => e
            render json: { error: "Invalid date format" }, status: :unprocessable_entity
          end

          def show
            authorize @order, :show?

            render json: {
              data: order_detail_json(@order)
            }, status: :ok
          rescue ActiveRecord::RecordNotFound => e
            render json: { error: "Order not found" }, status: :not_found
          end

          def mark_received
            authorize @order, :update?

            if %w[completed cancelled].include?(@order.status)
              render json: { error: "This order can no longer be marked as received" }, status: :unprocessable_entity
              return
            end

            ActiveRecord::Base.transaction do
              @order.update!(status: :received) unless @order.received?
              @order.fulfillments.update_all(status: "received", updated_at: Time.current)
              @order.award_received_bonus_point!
            end

            @order.reload
            render json: {
              data: order_detail_json(@order),
              bonus_awarded: 1
            }, status: :ok
          rescue ActiveRecord::RecordInvalid => e
            render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
          end

          def create
            order_params_raw = params.require(:order)
            order_params_data = order_params_raw.permit(
              :customer_address_id,
              phones: [],
              order_items: [ :variant_stock_id, :quantity ],
              fulfillments: [ :warehouse_id, order_items: [ :variant_stock_id, :quantity ] ]
            )

            customer_address = current_user.customer_addresses.find_by(id: order_params_data[:customer_address_id])
            unless customer_address
              render json: { error: "Address not found" }, status: :not_found
              return
            end

            order_items_params = (order_params_data[:order_items] || []).map do |item|
              {
                variant_stock_id: item[:variant_stock_id] || item["variant_stock_id"],
                quantity: (item[:quantity] || item["quantity"]).to_i
              }
            end

            fulfillments_params = (order_params_data[:fulfillments] || []).map do |fulfillment|
              {
                warehouse_id: fulfillment[:warehouse_id] || fulfillment["warehouse_id"],
                order_items: (fulfillment[:order_items] || fulfillment["order_items"] || []).map do |item|
                  {
                    variant_stock_id: item[:variant_stock_id] || item["variant_stock_id"],
                    quantity: (item[:quantity] || item["quantity"]).to_i
                  }
                end
              }
            end

            address_data = {
              customer_address_id: customer_address.id,
              name: customer_address.name,
              latitude: customer_address.latitude,
              longitude: customer_address.longitude
            }

            order = OrderService.new(
              current_user,
              order_items_params,
              fulfillments_params,
              address_data,
              (order_params_data[:phones] || [])
            ).create

            render json: { data: order_summary_json(order) }, status: :created
          rescue OrderService::ValidationError,
                 OrderService::AvailabilityConflictError,
                 OrderService::DowntimeConflictError => e
            render json: { error: e.message }, status: :unprocessable_entity
          rescue OrderService::RedisUnavailableError
            render json: { error: "Service temporarily unavailable" }, status: :service_unavailable
          end

          private

          def set_order
            @order = Order
              .includes(
                :user,
                :assigned_to,
                :customer_address,
                order_items: :variant_stock,
                fulfillments: :warehouse
              )
              .where(user_id: current_user.id)
              .where("orders.id::text = :id OR orders.order_id = :order_id", id: params[:id], order_id: params[:id].to_s.upcase)
              .first
            unless @order
              render json: { error: "Order not found" }, status: :not_found
            end
          end

          def order_summary_json(order)
            {
              id: order.id,
              type: "order",
              attributes: {
                status: order.status,
                order_id: order.order_id,
                payment_status: order.payment_status,
                delivery_distance: order.delivery_distance.to_f,
                delivery_fee: order.delivery_fee.to_f,
                item_subtotal: order.item_subtotal.to_f,
                total_amount: order.total_amount.to_f,
                total_price: order.total_price.to_f,
                created_at: order.created_at.iso8601,
                updated_at: order.updated_at.iso8601,
                creator_id: order.user_id,
                assigned_to: order.assigned_to && {
                  id: order.assigned_to.id,
                  email: order.assigned_to.email,
                  first_name: order.assigned_to.first_name,
                  last_name: order.assigned_to.last_name,
                  avatar: order.assigned_to.avatar
                },
                phones: order.phones || []
              }
            }
          end

          def order_detail_json(order)
            # Build customer address from association if present,
            # otherwise fall back to the snapshot stored on the order.
            customer_address_payload = begin
              addr_record = order.customer_address
              name = addr_record&.name || order.delivery_address_name
              lat  = addr_record&.latitude || order.delivery_latitude
              lng  = addr_record&.longitude || order.delivery_longitude

              # If we have no data at all, return nil so the key is null.
              unless name.present? || lat.present? || lng.present?
                nil
              else
                {
                  id: addr_record&.id,
                  type: "customer_address",
                  attributes: {
                    name: name,
                    latitude: lat&.to_f,
                    longitude: lng&.to_f,
                    country: addr_record&.country,
                    region: addr_record&.region,
                    city: addr_record&.city,
                    county: addr_record&.county,
                    address: addr_record&.address || {}
                  }
                }
              end
            end

            order_summary_json(order).merge(
              relationships: {
                customer_address: customer_address_payload,
                order_items: {
                  data: order.order_items.map do |item|
                    product = item.variant_stock&.product
                    {
                      id: item.id,
                      type: "order_item",
                      attributes: {
                        product_id: product&.id,
                        product_name: product&.name,
                        variant_stock_id: item.variant_stock_id,
                        quantity: item.quantity,
                        price: item.price.to_f,
                        image: variant_or_product_image(item, product),
                        snapshot: {
                          variant_stock_price: item.variant_stock_price&.to_f,
                          variant_stock_quantity: item.variant_stock_quantity,
                          variant_stock_option_names: item.variant_stock_option_names,
                          warehouse_name: item.variant_stock_warehouse_name,
                          warehouse_address: item.variant_stock_warehouse_address || {},
                          warehouse_latitude: item.variant_stock_warehouse_latitude&.to_f,
                          warehouse_longitude: item.variant_stock_warehouse_longitude&.to_f,
                          warehouse_country: item.variant_stock_warehouse_country,
                          warehouse_region: item.variant_stock_warehouse_region,
                          warehouse_city: item.variant_stock_warehouse_city,
                          warehouse_county: item.variant_stock_warehouse_county
                        }
                      }
                    }
                  end
                },
                fulfillments: {
                  data: order.fulfillments.map do |fulfillment|
                    warehouse = fulfillment.warehouse
                    {
                      id: fulfillment.id,
                      type: "fulfillment",
                      attributes: {
                        status: fulfillment.status,
                        delivery_date: fulfillment.delivery_date&.iso8601,
                        delivery_fee: fulfillment.delivery_fee&.to_f,
                        warehouse: warehouse && {
                          id: warehouse.id,
                          name: warehouse.name,
                          latitude: warehouse.latitude.to_f,
                          longitude: warehouse.longitude.to_f,
                          country: warehouse.country,
                          region: warehouse.region,
                          city: warehouse.city,
                          county: warehouse.county,
                          address: warehouse.address || {}
                        },
                        order_items: fulfillment.order_items.map do |item|
                          product = item.variant_stock&.product
                          {
                            id: item.id,
                            type: "order_item",
                            attributes: {
                              product_id: product&.id,
                              product_name: product&.name,
                              quantity: item.quantity,
                              price: item.price.to_f,
                              image: variant_or_product_image(item, product),
                              variant: {
                                option_names: item.variant_stock_option_names,
                                unit_price: item.variant_stock_price&.to_f,
                                total_stock_quantity: item.variant_stock_quantity
                              }
                            }
                          }
                        end
                      }
                    }
                  end
                }
              }
            )
          end

          # Returns a single image hash for a order_item:
          # - Prefer the latest image on any of the item's variant options
          # - Fall back to the latest product image
          # - Return nil if no image is available
          def variant_or_product_image(order_item, product)
            variant_stock = order_item.variant_stock

            if variant_stock
              option_with_image = variant_stock.variant_options.find do |opt|
                opt.images.any?
              end

              if option_with_image
                image = option_with_image.images.order(created_at: :desc).first
                return {
                  id: image.id,
                  url: image.url,
                  owner_type: "VariantOption",
                  owner_id: option_with_image.id,
                  created_at: image.created_at.iso8601,
                  updated_at: image.updated_at.iso8601
                }
              end
            end

            if product
              image = product.images.order(created_at: :desc).first
              if image
                return {
                  id: image.id,
                  url: image.url,
                  owner_type: "Product",
                  owner_id: product.id,
                  created_at: image.created_at.iso8601,
                  updated_at: image.updated_at.iso8601
                }
              end
            end

            nil
          end
        end
      end
    end
  end
end
