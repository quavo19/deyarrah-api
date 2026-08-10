class PaystackPaymentService
  class PaystackError < StandardError; end

  PAYSTACK_BASE_URL = "https://api.paystack.co".freeze

  def self.initialize_transaction(booking)
    raise PaystackError, "PAYSTACK_SECRET_KEY is not configured" if paystack_secret_key.blank?

    amount_kobo = (booking.total_price.to_f * 100).to_i
    raise PaystackError, "Amount must be greater than zero" if amount_kobo <= 0

    transaction = booking.transactions.create!(
      amount_kobo: amount_kobo,
      currency: "GHS",
      status: "initialized",
      provider: "paystack",
      provider_reference: SecureRandom.uuid
    )

    payload = {
      email: booking.user.email,
      amount: amount_kobo,
      reference: transaction.provider_reference,
      callback_url: ENV["PAYSTACK_CALLBACK_URL"]
    }.compact

    response_body = post("/transaction/initialize", payload)

    unless response_body["status"] == true
      message = response_body["message"] || "Failed to initialize Paystack transaction"
      raise PaystackError, message
    end

    data = response_body["data"] || {}
    authorization_url = data["authorization_url"]

    transaction.update!(
      status: "pending",
      metadata: {
        "authorization_url" => authorization_url,
        "paystack" => data
      }
    )

    {
      transaction: transaction,
      authorization_url: authorization_url,
      reference: transaction.provider_reference
    }
  end

  def self.verify_transaction(reference)
    raise PaystackError, "Reference is required" if reference.blank?
    raise PaystackError, "PAYSTACK_SECRET_KEY is not configured" if paystack_secret_key.blank?

    transaction = Transaction.find_by(provider_reference: reference)
    raise PaystackError, "Transaction not found" unless transaction

    response_body = get("/transaction/verify/#{reference}")

    unless response_body["status"] == true
      message = response_body["message"] || "Failed to verify Paystack transaction"
      raise PaystackError, message
    end

    data = response_body["data"] || {}
    paystack_status = data["status"]

    case paystack_status
    when "success"
      transaction.update!(
        status: "success",
        metadata: (transaction.metadata || {}).merge("verification" => data)
      )
      
      # Mark booking as paid when payment is successful
      booking = transaction.booking
      booking.update!(payment_status: :completed) unless booking.payment_status_completed?
    when "failed"
      transaction.update!(
        status: "failed",
        metadata: (transaction.metadata || {}).merge("verification" => data)
      )
    else
      transaction.update!(
        status: "pending",
        metadata: (transaction.metadata || {}).merge("verification" => data)
      )
    end

    transaction
  end

  def self.handle_webhook(payload)
    data = payload["data"] || {}
    reference = data["reference"] || payload["reference"]
    raise PaystackError, "Reference not found in webhook payload" if reference.blank?

    verify_transaction(reference)
  end

  def self.paystack_secret_key
    ENV["PAYSTACK_SECRET_KEY"]
  end

  def self.headers
    {
      "Authorization" => "Bearer #{paystack_secret_key}",
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end

  def self.post(path, payload)
    uri = URI.join(PAYSTACK_BASE_URL, path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = payload.to_json

    response = http.request(request)
    JSON.parse(response.body)
  rescue StandardError => e
    raise PaystackError, "Error calling Paystack: #{e.message}"
  end

  def self.get(path)
    uri = URI.join(PAYSTACK_BASE_URL, path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri, headers)

    response = http.request(request)
    JSON.parse(response.body)
  rescue StandardError => e
    raise PaystackError, "Error calling Paystack: #{e.message}"
  end
end

