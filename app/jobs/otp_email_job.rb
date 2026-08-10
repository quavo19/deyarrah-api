class OtpEmailJob < ApplicationJob
  queue_as :default

  sidekiq_options retry: 3

  def perform(user_id, otp_code)
    user = User.find(user_id)
    OtpMailer.send_otp(user, otp_code).deliver_now
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "OtpEmailJob failed: User #{user_id} not found"
    raise e
  end
end
