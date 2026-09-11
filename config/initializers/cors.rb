configured_origins = [
  ENV["FRONTEND_URL"],
  ENV["CUSTOMER_FRONTEND_URL"],
  ENV["API_BASE_URL"],
  *ENV.fetch("CORS_ORIGINS", "").split(",")
].compact.map(&:strip).reject(&:blank?)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*[
      "http://localhost:3002",
      "localhost:3002",
      "http://localhost:5173",
      "localhost:5173",
      "http://localhost:5174",
      "localhost:5174",
      "localhost:3001",
      *configured_origins
    ].uniq)

    resource "*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: [ :Authorization ]
  end
end
