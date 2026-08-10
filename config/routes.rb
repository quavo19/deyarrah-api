Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Authentication routes
      devise_for :users, path: "auth", path_names: {
        sign_in: "login",
        sign_out: "logout",
        registration: "signup",
        password: "password"
      },
      controllers: {
        sessions: "api/v1/auth/sessions",
        registrations: "api/v1/auth/registrations",
        passwords: "api/v1/auth/passwords"
      }

      # User management routes
      namespace :users do
        post "otp/verify", to: "otp#verify"
        post "otp/toggle", to: "otp#toggle"
        get "profile", to: "profile#show"
        put "profile", to: "profile#update"
        patch "profile", to: "profile#update"
        put "password", to: "passwords#update"
        patch "password", to: "passwords#update"
      end

      # Admin routes
      resources :roles, only: [ :index, :update ]
      resources :permissions, only: [ :index ]
      resources :categories, only: [ :index, :create, :destroy ]
      resources :contacts, only: [ :index, :create, :destroy ], controller: "contacts"

      # User management (admin only)
      resources :users, only: [ :index, :show ], controller: "users/users" do
        member do
          post "role/:role_id", to: "users/users#assign_role", as: "assign_role"
          post "permissions", to: "users/users#assign_permissions"
          delete "permissions", to: "users/users#unassign_permissions"
          post "block", to: "users/users#block"
          post "unblock", to: "users/users#unblock"
        end
      end

      # Payments
      namespace :payments do
        post "paystack/initialize", to: "paystack#initialize_payment"
        get "paystack/verify", to: "paystack#verify"
        post "paystack/webhook", to: "paystack#webhook"
      end

      namespace :products do
        resources :products, only: [ :index, :show, :create, :update, :destroy ] do
          resources :product_meta, only: [ :index, :create, :update, :destroy ], controller: "product_meta"
          resources :variants, only: [ :index, :create ], controller: "variants"
          resources :images, only: [ :index, :create, :destroy ], controller: "products/images", path_names: { images: "images" }
        end
        resources :variants, only: [ :show, :update, :destroy ], controller: "variants" do
          get "options", to: "variants#index_options"
          post "options", to: "variants#create_option"
          put "options/:option_id", to: "variants#update_option"
          patch "options/:option_id", to: "variants#update_option"
          delete "options/:option_id", to: "variants#destroy_option"
          get "options/:option_id/images", to: "variants/images#index"
          post "options/:option_id/images", to: "variants/images#create"
          delete "options/:option_id/images/:id", to: "variants/images#destroy"
        end
        resources :images, only: [ :index, :create, :update, :destroy ], controller: "images"
      end

      namespace :inventory do
        resources :variant_stocks, only: [ :index, :show, :create, :update, :destroy ]
        resources :downtimes, only: [ :index, :create, :show, :update, :destroy ] do
          member do
            post :end_early
          end
        end
      end

      resources :bookings, only: [ :index, :create, :show, :update, :destroy ], controller: "bookings/bookings" do
        member do
          post :cancel
        end
      end

      resources :warehouses, only: [ :index, :create, :show, :update, :destroy ] do
        resources :images, only: [ :index, :create, :destroy ], controller: "warehouses/images"
      end

      # Customer routes
      namespace :customer do
        resources :products, only: [ :index, :show ], controller: "products/products"
        resources :addresses, only: [ :index, :show, :create, :update, :destroy ], controller: "addresses/addresses" do
          member do
            post :set_default
          end
        end
        resources :warehouses, only: [ :index ], controller: "warehouses/warehouses"
        namespace :bookings do
          resources :bookings, only: [ :index, :show ], controller: "bookings"
        end
      end

      # Customer admin / staff booking management routes
      namespace :customer_admin do
        namespace :bookings do
          resources :bookings, only: [ :index, :show, :update ], controller: "bookings" do
            collection do
              get :assigned
            end
          end
        end
      end
    end
  end

  # Sidekiq Web UI
  # In development: open access
  # In production: requires HTTP Basic Auth (set SIDEKIQ_USERNAME and SIDEKIQ_PASSWORD env vars)
  if defined?(Sidekiq::Web)
    if Rails.env.development?
      mount Sidekiq::Web => "/sidekiq"
    elsif Rails.env.production?
      # Add HTTP Basic Auth for production
      require "rack/auth/basic"
      Sidekiq::Web.use Rack::Auth::Basic do |username, password|
        ActiveSupport::SecurityUtils.secure_compare(
          ::Digest::SHA256.hexdigest(username),
          ::Digest::SHA256.hexdigest(ENV.fetch("SIDEKIQ_USERNAME", ""))
        ) &
        ActiveSupport::SecurityUtils.secure_compare(
          ::Digest::SHA256.hexdigest(password),
          ::Digest::SHA256.hexdigest(ENV.fetch("SIDEKIQ_PASSWORD", ""))
        )
      end
      mount Sidekiq::Web => "/sidekiq"
    end
  end
end
