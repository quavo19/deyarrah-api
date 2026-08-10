require "sidekiq"

# Use Redis database 2 for this project (database 1 is being used by WanaownBackend)
# You can change this by setting REDIS_URL environment variable
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/2") }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/2") }
end

# Load Sidekiq Web UI for routes (available in all environments)
require "sidekiq/web"
