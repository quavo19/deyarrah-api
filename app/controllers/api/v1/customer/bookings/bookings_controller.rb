module Api
  module V1
    module Customer
      module Bookings
        class BookingsController < BaseController
          before_action :authenticate_user!
          before_action :set_booking, only: [ :show ]

          def index
            @bookings = Booking.where(user_id: current_user.id)
              .includes(
                :product,
                booking_items: :variant_stock,
                fulfillments: :warehouse
              )
              .order(created_at: :desc)

            # Filter by status if provided
            if params[:status].present?
              @bookings = @bookings.where(status: params[:status])
            end

            # Filter by date range if provided
            if params[:start_date].present?
              @bookings = @bookings.where("start_at >= ?", Time.parse(params[:start_date]))
            end

            if params[:end_date].present?
              @bookings = @bookings.where("end_at <= ?", Time.parse(params[:end_date]))
            end

            # Kaminari pagination
            page = params[:page] || 1
            per_page = params[:per_page] || 25
            @bookings = @bookings.page(page).per(per_page)

            render json: {
              data: @bookings.map do |booking|
                {
                  id: booking.id,
                  type: "booking",
                  attributes: {
                    product_id: booking.product_id,
                    product_name: booking.product&.name,
                    start_at: booking.start_at.iso8601,
                    end_at: booking.end_at.iso8601,
                    status: booking.status,
                    payment_status: booking.payment_status,
                    delivery_distance: booking.delivery_distance.to_f,
                    delivery_fee: booking.delivery_fee.to_f,
                    item_subtotal: booking.item_subtotal.to_f,
                    total_amount: booking.total_amount.to_f,
                    total_price: booking.total_price.to_f,
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
                            price: item.price.to_f
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
                current_page: @bookings.current_page,
                per_page: @bookings.limit_value,
                total_pages: @bookings.total_pages,
                total_count: @bookings.total_count
              }
            }, status: :ok
          rescue ArgumentError => e
            render json: { error: "Invalid date format" }, status: :unprocessable_entity
          end

          def show
            authorize @booking, :show?

            render json: {
              data: booking_detail_json(@booking)
            }, status: :ok
          rescue ActiveRecord::RecordNotFound => e
            render json: { error: "Booking not found" }, status: :not_found
          end

          private

          def set_booking
            @booking = Booking
              .includes(
                :user,
                :assigned_to,
                :customer_address,
                product: :images,
                booking_items: :variant_stock,
                fulfillments: :warehouse
              )
              .where(user_id: current_user.id)
              .find_by(id: params[:id])
            unless @booking
              render json: { error: "Booking not found" }, status: :not_found
            end
          end

          def booking_summary_json(booking)
            {
              id: booking.id,
              type: "booking",
              attributes: {
                product_id: booking.product_id,
                product_name: booking.product_name || booking.product&.name,
                start_at: booking.start_at.iso8601,
                end_at: booking.end_at.iso8601,
                status: booking.status,
                payment_status: booking.payment_status,
                delivery_distance: booking.delivery_distance.to_f,
                delivery_fee: booking.delivery_fee.to_f,
                item_subtotal: booking.item_subtotal.to_f,
                total_amount: booking.total_amount.to_f,
                total_price: booking.total_price.to_f,
                created_at: booking.created_at.iso8601,
                updated_at: booking.updated_at.iso8601,
                creator_id: booking.user_id,
                assigned_to: booking.assigned_to && {
                  id: booking.assigned_to.id,
                  email: booking.assigned_to.email,
                  first_name: booking.assigned_to.first_name,
                  last_name: booking.assigned_to.last_name,
                  avatar: booking.assigned_to.avatar
                },
                phones: booking.phones || []
              }
            }
          end

          def booking_detail_json(booking)
            # Build customer address from association if present,
            # otherwise fall back to the snapshot stored on the booking.
            customer_address_payload = begin
              addr_record = booking.customer_address
              name = addr_record&.name || booking.delivery_address_name
              lat  = addr_record&.latitude || booking.delivery_latitude
              lng  = addr_record&.longitude || booking.delivery_longitude

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

            booking_summary_json(booking).merge(
              relationships: {
                customer_address: customer_address_payload,
                booking_items: {
                  data: booking.booking_items.map do |item|
                    product = booking.product
                    {
                      id: item.id,
                      type: "booking_item",
                      attributes: {
                        product_id: booking.product_id,
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
                  data: booking.fulfillments.map do |fulfillment|
                    warehouse = fulfillment.warehouse
                    product = booking.product
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
                        product: product && {
                          id: product.id,
                          name: booking.product_name || product.name,
                          description: booking.product_description || product.description,
                          bookable_type: booking.product_bookable_type || product.bookable_type,
                          images: product.images.order(created_at: :desc).map do |image|
                            {
                              id: image.id,
                              url: image.url,
                              created_at: image.created_at.iso8601,
                              updated_at: image.updated_at.iso8601
                            }
                          end
                        },
                        booking_items: fulfillment.booking_items.map do |item|
                          {
                            id: item.id,
                            type: "booking_item",
                            attributes: {
                              product_id: booking.product_id,
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

          # Returns a single image hash for a booking_item:
          # - Prefer the latest image on any of the item's variant options
          # - Fall back to the latest product image
          # - Return nil if no image is available
          def variant_or_product_image(booking_item, product)
            variant_stock = booking_item.variant_stock

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
