class WelcomeEmailJob < ApplicationJob
  queue_as :default

  # Retry email jobs up to 3 times (emails are less critical than other jobs)
  # After 3 retries, the job will be moved to the Dead Job Queue
  sidekiq_options retry: 3

  def perform(user_id)
    user = User.find(user_id)
    WelcomeMailer.welcome_email(user).deliver_now
  rescue ActiveRecord::RecordNotFound => e
    # User was deleted, no need to retry
    Rails.logger.error "WelcomeEmailJob failed: User #{user_id} not found"
    raise e
  end
end
