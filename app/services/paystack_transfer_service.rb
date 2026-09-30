class PaystackTransferService
  class PaystackTransferError < StandardError; end

  PROVIDER_CODE_ENV_KEYS = {
    "mtn" => "PAYSTACK_GH_MTN_MOMO_CODE",
    "vodafone" => "PAYSTACK_GH_VODAFONE_MOMO_CODE",
    "airteltigo" => "PAYSTACK_GH_AIRTELTIGO_MOMO_CODE"
  }.freeze

  def self.initiate_withdrawal!(withdrawal)
    withdrawal.with_lock do
      raise PaystackTransferError, "Withdrawal must be approved before payment" unless withdrawal.status == "approved"

      existing_transaction = withdrawal.payout_transaction
      if existing_transaction&.success?
        raise PaystackTransferError, "Withdrawal has already been paid"
      elsif existing_transaction&.pending? || existing_transaction&.initialized?
        raise PaystackTransferError, "Withdrawal payment is already being processed"
      end

      details = withdrawal.payout_details || {}
      reference = "AFF-WD-#{withdrawal.id}"
      transaction = existing_transaction || withdrawal.create_payout_transaction!(
        user: withdrawal.affiliate_user,
        amount_kobo: (withdrawal.amount.to_d * 100).to_i,
        currency: withdrawal.currency,
        status: "initialized",
        provider: "paystack",
        provider_reference: reference,
        purpose: "affiliate_withdrawal_payout",
        direction: "debit"
      )

      begin
        recipient_code = details["paystack_recipient_code"].presence || create_transfer_recipient(details)["recipient_code"]
        raise PaystackTransferError, "Unable to create transfer recipient" if recipient_code.blank?

        transaction.update!(status: "pending")

        transfer_data = initiate_transfer(
          amount: withdrawal.amount,
          recipient_code: recipient_code,
          reference: reference,
          reason: "Affiliate withdrawal"
        )

        withdrawal.update!(
          status: "paid",
          paid_at: Time.current,
          payout_details: details.merge(
            "paystack_recipient_code" => recipient_code,
            "paystack_transfer_code" => transfer_data["transfer_code"],
            "paystack_reference" => reference,
            "paystack_transfer" => transfer_data
          )
        )

        transaction.update!(
          status: "success",
          processed_at: Time.current,
          metadata: (transaction.metadata || {}).merge("paystack_transfer" => transfer_data)
        )

        transfer_data
      rescue PaystackTransferError => e
        transaction.update!(
          status: "failed",
          processed_at: Time.current,
          metadata: (transaction.metadata || {}).merge("error" => e.message)
        )
        raise
      end
    end
  end

  def self.create_transfer_recipient(details)
    provider_code = provider_code_for(details["provider"])
    payload = {
      type: "mobile_money",
      name: details["account_name"],
      account_number: details["phone_number"],
      bank_code: provider_code,
      currency: "GHS"
    }

    response_body = post("/transferrecipient", payload)
    raise_error_from(response_body, "Failed to create Paystack transfer recipient")

    response_body["data"] || {}
  end

  def self.initiate_transfer(amount:, recipient_code:, reference:, reason:)
    payload = {
      source: "balance",
      amount: (amount.to_d * 100).to_i,
      recipient: recipient_code,
      reference: reference,
      reason: reason
    }

    response_body = post("/transfer", payload)
    raise_error_from(response_body, "Failed to initiate Paystack transfer")

    response_body["data"] || {}
  end

  def self.provider_code_for(provider)
    provider_code = ENV[PROVIDER_CODE_ENV_KEYS[provider.to_s]]
    return provider_code if provider_code.present?

    raise PaystackTransferError, "Paystack mobile money provider code is not configured"
  end

  def self.paystack_secret_key
    ENV["PAYSTACK_SECRET_KEY"]
  end

  def self.headers
    raise PaystackTransferError, "PAYSTACK_SECRET_KEY is not configured" if paystack_secret_key.blank?

    {
      "Authorization" => "Bearer #{paystack_secret_key}",
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end

  def self.post(path, payload)
    uri = URI.join(PaystackPaymentService::PAYSTACK_BASE_URL, path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = payload.to_json

    response = http.request(request)
    JSON.parse(response.body)
  rescue PaystackTransferError
    raise
  rescue StandardError => e
    raise PaystackTransferError, "Error calling Paystack: #{e.message}"
  end

  def self.raise_error_from(response_body, fallback)
    return if response_body["status"] == true

    raise PaystackTransferError, response_body["message"] || fallback
  end
end
