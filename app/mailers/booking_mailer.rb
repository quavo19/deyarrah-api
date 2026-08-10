class BookingMailer < ApplicationMailer
  # Booking Canceled - send to customer
  def booking_canceled(booking)
    @booking = booking
    @user = booking.user
    @product = booking.product
    @booking_items = booking.booking_items.includes(:variant_stock)
    @fulfillments = booking.fulfillments.includes(:warehouse, booking_items: :variant_stock)
    @frontend_url = ENV.fetch("FRONTEND_URL", "https://platinumvaultltd.com")
    @booking_url = "#{@frontend_url}/bookings/#{booking.id}"

    mail(
      to: @user.email,
      subject: "Your booking has been canceled - #{booking.product_name || 'Booking'} ##{booking.id.to_s.first(8)}"
    )
  end

  # Dispatched - send to admins/super admins
  def booking_dispatched(booking, fulfillment = nil)
    @booking = booking
    @user = booking.user
    @fulfillment = fulfillment
    @product = booking.product
    @booking_items = fulfillment ? fulfillment.booking_items.includes(:variant_stock) : booking.booking_items.includes(:variant_stock)
    @warehouse = fulfillment&.warehouse || booking.fulfillments.first&.warehouse
    @frontend_url = ENV.fetch("FRONTEND_URL", "https://platinumvaultltd.com")
    @booking_url = "#{@frontend_url}/bookings/#{booking.id}"

    admin_emails = User.joins(:role).where(roles: { name: [ "ADMIN", "SUPER_ADMIN" ] }).pluck(:email)
    return if admin_emails.empty?

    mail(
      to: admin_emails,
      subject: "Booking dispatched - #{booking.product_name || 'Booking'} ##{booking.id.to_s.first(8)}"
    )
  end

  # Returning - send to assigned staff and admins
  def booking_returning(booking, fulfillment = nil)
    @booking = booking
    @user = booking.user
    @fulfillment = fulfillment
    @product = booking.product
    @booking_items = fulfillment ? fulfillment.booking_items.includes(:variant_stock) : booking.booking_items.includes(:variant_stock)
    @warehouse = fulfillment&.warehouse || booking.fulfillments.first&.warehouse
    @frontend_url = ENV.fetch("FRONTEND_URL", "https://platinumvaultltd.com")
    @booking_url = "#{@frontend_url}/bookings/#{booking.id}"

    recipients = []
    recipients << booking.assigned_to.email if booking.assigned_to.present?
    recipients += User.joins(:role).where(roles: { name: [ "ADMIN", "SUPER_ADMIN" ] }).pluck(:email)
    recipients.uniq!

    return if recipients.empty?

    mail(
      to: recipients,
      subject: "Booking returning - #{booking.product_name || 'Booking'} ##{booking.id.to_s.first(8)}"
    )
  end

  # Completed - send to customer, assigned staff, and admins/super admins
  def booking_completed(booking, fulfillment = nil)
    @booking = booking
    @user = booking.user
    @fulfillment = fulfillment
    @product = booking.product
    @booking_items = fulfillment ? fulfillment.booking_items.includes(:variant_stock) : booking.booking_items.includes(:variant_stock)
    @warehouse = fulfillment&.warehouse || booking.fulfillments.first&.warehouse
    @frontend_url = ENV.fetch("FRONTEND_URL", "https://platinumvaultltd.com")
    @booking_url = "#{@frontend_url}/bookings/#{booking.id}"

    recipients = [ booking.user.email ]
    recipients << booking.assigned_to.email if booking.assigned_to.present?
    recipients += User.joins(:role).where(roles: { name: [ "ADMIN", "SUPER_ADMIN" ] }).pluck(:email)
    recipients.uniq!

    mail(
      to: recipients,
      subject: "Booking completed - #{booking.product_name || 'Booking'} ##{booking.id.to_s.first(8)}"
    )
  end

  # Confirmed - send to customer, admins/super admins
  def booking_confirmed(booking, fulfillment = nil)
    @booking = booking
    @user = booking.user
    @fulfillment = fulfillment
    @product = booking.product
    @booking_items = fulfillment ? fulfillment.booking_items.includes(:variant_stock) : booking.booking_items.includes(:variant_stock)
    @warehouse = fulfillment&.warehouse || booking.fulfillments.first&.warehouse
    @frontend_url = ENV.fetch("FRONTEND_URL", "https://platinumvaultltd.com")
    @booking_url = "#{@frontend_url}/bookings/#{booking.id}"

    recipients = [ booking.user.email ]
    recipients += User.joins(:role).where(roles: { name: [ "ADMIN", "SUPER_ADMIN" ] }).pluck(:email)
    recipients.uniq!

    mail(
      to: recipients,
      subject: "Booking confirmed - #{booking.product_name || 'Booking'} ##{booking.id.to_s.first(8)}"
    )
  end

  # Received - send to assigned staff, admins, super admins, and customer
  def booking_received(booking, fulfillment = nil)
    @booking = booking
    @user = booking.user
    @fulfillment = fulfillment
    @product = booking.product
    @booking_items = fulfillment ? fulfillment.booking_items.includes(:variant_stock) : booking.booking_items.includes(:variant_stock)
    @warehouse = fulfillment&.warehouse || booking.fulfillments.first&.warehouse
    @frontend_url = ENV.fetch("FRONTEND_URL", "https://platinumvaultltd.com")
    @booking_url = "#{@frontend_url}/bookings/#{booking.id}"

    recipients = [ booking.user.email ]
    recipients << booking.assigned_to.email if booking.assigned_to.present?
    recipients += User.joins(:role).where(roles: { name: [ "ADMIN", "SUPER_ADMIN" ] }).pluck(:email)
    recipients.uniq!

    mail(
      to: recipients,
      subject: "Booking received - #{booking.product_name || 'Booking'} ##{booking.id.to_s.first(8)}"
    )
  end

  # Booking assigned - send to assigned staff
  def booking_assigned(booking)
    return unless booking.assigned_to.present?

    @booking = booking
    @user = booking.assigned_to
    @product = booking.product
    @booking_items = booking.booking_items.includes(:variant_stock)
    @fulfillments = booking.fulfillments.includes(:warehouse, booking_items: :variant_stock)
    @frontend_url = ENV.fetch("FRONTEND_URL", "https://platinumvaultltd.com")
    @booking_url = "#{@frontend_url}/bookings/#{booking.id}"

    mail(
      to: @user.email,
      subject: "New booking assigned to you - #{booking.product_name || 'Booking'} ##{booking.id.to_s.first(8)}"
    )
  end

  # Booking created - send to admins/super admins
  def booking_created(booking)
    @booking = booking
    @user = booking.user
    @product = booking.product
    @booking_items = booking.booking_items.includes(:variant_stock)
    @fulfillments = booking.fulfillments.includes(:warehouse, booking_items: :variant_stock)
    @frontend_url = ENV.fetch("FRONTEND_URL", "https://platinumvaultltd.com")
    @booking_url = "#{@frontend_url}/bookings/#{booking.id}"

    admin_emails = User.joins(:role).where(roles: { name: [ "ADMIN", "SUPER_ADMIN" ] }).pluck(:email)
    return if admin_emails.empty?

    mail(
      to: admin_emails,
      subject: "New booking created - #{booking.product_name || 'Booking'} ##{booking.id.to_s.first(8)}"
    )
  end

  # Booking created - send to customer
  def booking_created_customer(booking)
    @booking = booking
    @user = booking.user
    @product = booking.product
    @booking_items = booking.booking_items.includes(:variant_stock)
    @fulfillments = booking.fulfillments.includes(:warehouse, booking_items: :variant_stock)
    @frontend_url = ENV.fetch("FRONTEND_URL", "https://platinumvaultltd.com")
    @booking_url = "#{@frontend_url}/bookings/#{booking.id}"

    mail(
      to: @user.email,
      subject: "Your booking has been created - #{booking.product_name || 'Booking'} ##{booking.id.to_s.first(8)}"
    )
  end
end
