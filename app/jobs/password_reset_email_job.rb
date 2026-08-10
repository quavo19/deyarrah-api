class PasswordResetEmailJob < ApplicationJob
  queue_as :default

  sidekiq_options retry: 3

  def perform(user_id, reset_token)
    user = User.find(user_id)
    PasswordResetMailer.reset_password_email(user, reset_token).deliver_now
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "PasswordResetEmailJob failed: User #{user_id} not found"
    raise e
  end
end
