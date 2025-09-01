Rails.application.routes.draw do
  namespace :admin do
    get "dashboard/index"
    get "login" => "sessions#new"
    post "login" => "sessions#create"
    delete "logout" => "sessions#destroy"
    get "dashboard" => "dashboard#index", as: :dashboard
    resources :tenants do
      collection do
        delete :delete_all, to: "tenants#delete_all", as: :delete_all
      end
      resources :sites do
        collection do
          delete :delete_all, to: "sites#delete_all", as: :delete_all
        end
        resources :nas do
          collection do
            delete :delete_all, to: "nas#delete_all", as: :delete_all
          end
        end
      end
      resources :clients do
        collection do
          delete :delete_all, to: "clients#delete_all", as: :delete_all
          post :import, to: "clients#import", as: :import
        end
      end
      resources :users do
        collection do
          delete :delete_all, to: "users#delete_all", as: :delete_all
        end
      end
      resources :radius_devices, only: [:index, :show] do
        member do
          post :enable_radius
          delete :disable_radius
          post :regenerate_otp
          post :reset_failures
        end
        collection do
          post :bulk_enable
          post :bulk_disable
        end
      end
    end
    resources :clients do
      resources :devices do
        collection do
          delete :delete_all, to: "devices#delete_all", as: :delete_all
        end
      end
    end
  end

  # RADIUS API endpoints for FreeRADIUS integration
  namespace :api do
    namespace :radius do
      post :authenticate
      post :authorize
      post :accounting
      get :status
      
      # NAS client management
      resources :clients, only: [:index, :create, :show, :update, :destroy] do
        member do
          post :test_connection
        end
      end
      post 'clients/generate_config', to: 'clients#generate_config'
      post 'clients/reload_freeradius', to: 'clients#reload_freeradius'
    end
  end

  put "/toggle_active", to: "toggle_active#update", as: :toggle_active

  get "/check_pnr", to: "pnumber#check_pnr", as: :check_pnr
  get "/check_phone", to: "pnumber#check_phone", as: :check_phone
  
  # WiFi Portal Routes
  get "wifi", to: "wifi_portal#index", as: :wifi_portal
  get "wifi/setup/:token", to: "wifi_portal#setup", as: :wifi_setup
  post "wifi/verify_phone", to: "wifi_portal#verify_phone"
  post "wifi/verify_email", to: "wifi_portal#verify_email"
  post "wifi/verify_otp", to: "wifi_portal#verify_otp"
  get "wifi/dashboard", to: "wifi_portal#dashboard", as: :wifi_dashboard
  post "wifi/enable_device_radius", to: "wifi_portal#enable_device_radius"
  post "wifi/regenerate_otp", to: "wifi_portal#regenerate_otp"
  post "wifi/disable_device_radius", to: "wifi_portal#disable_device_radius"
  get "wifi/instructions/:device_id", to: "wifi_portal#instructions", as: :wifi_instructions

  resource :session, only: [ :create, :update ]
  get "/guest/s/:site_name", to: "sessions#new", as: :new_session, constraints: { format: "html" }
  resolve("Session") { [ :session ] }
  get "otp", to: "sessions#otp", as: :otp
  get "success", to: "sessions#success", as: :success
  post "resend_otp", to: "sessions#resend", as: :resend_otp
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "admin/tenants#index"
end
