Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "https://platinumvaultltd.com", # later change to the domain of the frontend app
            "platinumvaultltd.com",
            "https://api.platinumvaultltd.com",
            "api.platinumvaultltd.com",
            "https://cms.platinumvaultltd.com",
            "cms.platinumvaultltd.com",
            "http://localhost:3002",
            "localhost:3002",
            "http://localhost:5173",
            "localhost:5173",
            "localhost:3001",
            "www.platinumvaultltd.com",
            "https://www.platinumvaultltd.com"

    resource "*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: [ :Authorization ]
  end
end
