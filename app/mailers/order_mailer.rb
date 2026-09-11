class OrderMailer < ApplicationMailer
  # Order Canceled - send to customer
  def order_canceled(order)
    setup_order(order)

    mail(
      to: @user.email,
      subject: "Your order has been canceled - Order ##{order.order_id}"
    )
  end

  # Dispatched - send to admins/super admins
  def order_dispatched(order, fulfillment = nil)
    setup_order(order, fulfillment)
    @fulfillment = fulfillment

    admin_emails = User.joins(:role).where(roles: { name: [ "ADMIN", "SUPER_ADMIN" ] }).pluck(:email)
    return if admin_emails.empty?

    mail(
      to: admin_emails,
      subject: "Order dispatched - Order ##{order.order_id}"
    )
  end

  # Returning - send to assigned staff and admins
  def order_returning(order, fulfillment = nil)
    setup_order(order, fulfillment)
    @fulfillment = fulfillment

    recipients = []
    recipients << order.assigned_to.email if order.assigned_to.present?
    recipients += User.joins(:role).where(roles: { name: [ "ADMIN", "SUPER_ADMIN" ] }).pluck(:email)
    recipients.uniq!

    return if recipients.empty?

    mail(
      to: recipients,
      subject: "Order returning - Order ##{order.order_id}"
    )
  end

  # Completed - send to customer, assigned staff, and admins/super admins
  def order_completed(order, fulfillment = nil)
    setup_order(order, fulfillment)
    @fulfillment = fulfillment

    recipients = [ order.user.email ]
    recipients << order.assigned_to.email if order.assigned_to.present?
    recipients += User.joins(:role).where(roles: { name: [ "ADMIN", "SUPER_ADMIN" ] }).pluck(:email)
    recipients.uniq!

    mail(
      to: recipients,
      subject: "Order completed - Order ##{order.order_id}"
    )
  end

  # Confirmed - send to customer, admins/super admins
  def order_confirmed(order, fulfillment = nil)
    setup_order(order, fulfillment)
    @fulfillment = fulfillment

    recipients = [ order.user.email ]
    recipients += User.joins(:role).where(roles: { name: [ "ADMIN", "SUPER_ADMIN" ] }).pluck(:email)
    recipients.uniq!

    mail(
      to: recipients,
      subject: "Order confirmed - Order ##{order.order_id}"
    )
  end

  # Received - send to assigned staff, admins, super admins, and customer
  def order_received(order, fulfillment = nil)
    setup_order(order, fulfillment)
    @fulfillment = fulfillment

    recipients = [ order.user.email ]
    recipients << order.assigned_to.email if order.assigned_to.present?
    recipients += User.joins(:role).where(roles: { name: [ "ADMIN", "SUPER_ADMIN" ] }).pluck(:email)
    recipients.uniq!

    mail(
      to: recipients,
      subject: "Order received - Order ##{order.order_id}"
    )
  end

  # Order assigned - send to assigned staff
  def order_assigned(order)
    return unless order.assigned_to.present?

    setup_order(order)
    @user = order.assigned_to

    mail(
      to: @user.email,
      subject: "New order assigned to you - Order ##{order.order_id}"
    )
  end

  # Order created - send to admins/super admins
  def order_created(order)
    setup_order(order)

    admin_emails = User.joins(:role).where(roles: { name: [ "ADMIN", "SUPER_ADMIN" ] }).pluck(:email)
    return if admin_emails.empty?

    mail(
      to: admin_emails,
      subject: "New order created - Order ##{order.order_id}"
    )
  end

  # Order created - send to customer
  def order_created_customer(order)
    setup_order(order)

    mail(
      to: @user.email,
      subject: "Your order has been created - Order ##{order.order_id}"
    )
  end

  private

  def setup_order(order, fulfillment = nil)
    @order = order
    @user = order.user
    @order_items = fulfillment ? fulfillment.order_items.includes(variant_stock: :product) : order.order_items.includes(variant_stock: :product)
    @product = @order_items.first&.variant_stock&.product
    @fulfillments = order.fulfillments.includes(:warehouse, order_items: :variant_stock)
    @warehouse = fulfillment&.warehouse || order.fulfillments.first&.warehouse
    @frontend_url = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
    @order_url = "#{@frontend_url}/orders/#{order.id}"
  end
end
