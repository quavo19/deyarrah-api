class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  # Sidekiq default: retries 25 times with exponential backoff
  # You can override this per job or configure globally here
  # For example, to set max retries globally:
  # sidekiq_options retry: 5
end
