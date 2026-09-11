module Api
  module V1
    module CustomerAdmin
      module Orders
        class OrdersController < BaseController
          before_action :authenticate_user!
          before_action :set_order, only: [ :show, :update ]

          # GET /api/v1/customer_admin/orders/orders
          # - Admins: all orders
          # - Non-admins: orders they created OR that are assigned to them
          def index
            authorize Order, :index?

            orders = base_scope

            # Filters
            orders = orders.where(status: params[:status]) if params[:status].present?
            if params[:search].present?
              term = "%#{params[:search]}%"
              orders = orders.where(
                "orders.id::text ILIKE :term OR users.email ILIKE :term OR users.first_name ILIKE :term OR users.last_name ILIKE :term",
                term: term
              )
            end

            # Pagination
            page = (params[:page] || 1).to_i
            per_page = (params[:per_page] || 25).to_i
            orders = orders.page(page).per(per_page)

            render json: {
              data: orders.map { |b| order_summary_json(b) },
              meta: {
                current_page: orders.current_page,
                per_page: orders.limit_value,
                total_pages: orders.total_pages,
                total_count: orders.total_count
              }
            }, status: :ok
          rescue ArgumentError
            render json: { error: "Invalid date format" }, status: :unprocessable_entity
          end

          # GET /api/v1/customer_admin/orders/orders/assigned
          # - Admins: all assigned orders
          # - Others: orders assigned_to current_user
          def assigned
            authorize Order, :index?

            orders = Order
              .includes(
                :user,
                :assigned_to,
                :customer_address,
                order_items: :variant_stock,
                fulfillments: :warehouse
              )

            if admin_user?
              orders = orders.where.not(assigned_to_id: nil)
            else
              orders = orders.where(assigned_to_id: current_user.id)
            end

            # Optional status filter
            orders = orders.where(status: params[:status]) if params[:status].present?

            page = (params[:page] || 1).to_i
            per_page = (params[:per_page] || 25).to_i
            orders = orders.page(page).per(per_page)

            render json: {
              data: orders.map { |b| order_summary_json(b) },
              meta: {
                current_page: orders.current_page,
                per_page: orders.limit_value,
                total_pages: orders.total_pages,
                total_count: orders.total_count
              }
            }, status: :ok
          end

          # GET /api/v1/customer_admin/orders/orders/:id
          # Returns full order details
          def show
            authorize @order, :show?

            render json: {
              data: order_detail_json(@order)
            }, status: :ok
          end

          # PATCH/PUT /api/v1/customer_admin/orders/orders/:id
          # - Admins: can update order assignment and fulfillment statuses
          # - Others: can update fulfillment statuses only for orders assigned to them
          def update
            authorize @order, :update?

            unless can_update_order?(@order)
              render json: { error: "You are not allowed to update this order" }, status: :forbidden
              return
            end

            # Owner (customer) may only set order status to received or returning
            if owner_updating_status? && params[:status].present?
              allowed = %w[received returning]
              unless allowed.include?(params[:status].to_s)
                render json: { error: "As the customer, you may only update status to received or returning" }, status: :forbidden
                return
              end
            end

            ActiveRecord::Base.transaction do
              # Admin can reassign order
              if admin_user? && params[:assigned_to_id].present?
                @order.update!(assigned_to_id: params[:assigned_to_id])
              end

              # Update fulfillment statuses
              fulfillments_param = params[:fulfillments]

              if fulfillments_param.present?
                unless fulfillments_param.is_a?(Array)
                  render json: { error: "fulfillments must be an array" }, status: :unprocessable_entity
                  raise ActiveRecord::Rollback
                end

                allowed_statuses = owner_updating_status? ? %w[received returning] : nil

                fulfillments_param.each do |f_params|
                  f_id = f_params[:id] || f_params["id"]
                  status = f_params[:status] || f_params["status"]

                  next unless f_id.present? && status.present?

                  if allowed_statuses && !allowed_statuses.include?(status.to_s)
                    render json: { error: "As the customer, you may only set fulfillment status to received or returning" }, status: :forbidden
                    raise ActiveRecord::Rollback
                  end

                  fulfillment = @order.fulfillments.find_by(id: f_id)
                  unless fulfillment
                    render json: { error: "Fulfillment #{f_id} not found for this order" }, status: :not_found
                    raise ActiveRecord::Rollback
                  end

                  fulfillment.update!(status: status)
                end
              elsif params[:status].present?
                # Backward compatibility: if no fulfillments array is provided,
                # apply the status to the order itself and to all fulfillments.
                @order.update!(status: params[:status])
                @order.fulfillments.update_all(status: params[:status])
              end
            end

            @order.reload

            render json: {
              data: order_detail_json(@order)
            }, status: :ok
          rescue ActiveRecord::RecordInvalid => e
            render json: {
              error: "Validation failed",
              errors: [ e.message ]
            }, status: :unprocessable_entity
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
              .where("orders.id::text = :id OR orders.order_id = :order_id", id: params[:id], order_id: params[:id].to_s.upcase)
              .first
            unless @order
              render json: { error: "Order not found" }, status: :not_found
              nil
            end
          end

          # Base scope for index, respecting role:
          # - Admin: all orders
          # - Others: created by or assigned to current_user
          def base_scope
            scope = Order
              .includes(
                :user,
                :assigned_to,
                :customer_address,
                order_items: :variant_stock,
                fulfillments: :warehouse
              )
              .references(:user)
              .order(created_at: :desc)

            return scope if admin_user?

            scope.where("orders.user_id = :uid OR orders.assigned_to_id = :uid", uid: current_user.id)
          end

          def admin_user?
            role_name = current_user&.role&.name
            role_name == "ADMIN" || role_name == "SUPER_ADMIN"
          end

          # Admins: full update. Assigned staff: full update. Owner (customer): can update to received/returning only.
          def can_update_order?(order)
            return true if admin_user?
            return true if order.assigned_to_id == current_user.id
            return true if order.user_id == current_user.id
            false
          end

          def owner_updating_status?
            !admin_user? && @order.assigned_to_id != current_user.id && @order.user_id == current_user.id
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
                phones: order.phones || [],
                customer: {
                  id: order.user.id,
                  email: order.user.email,
                  first_name: order.user.first_name,
                  last_name: order.user.last_name,
                  avatar: order.user.avatar
                },
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
