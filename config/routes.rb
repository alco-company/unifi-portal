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
    end
    resources :clients do
      resources :devices do
        collection do
          delete :delete_all, to: "devices#delete_all", as: :delete_all
        end
      end
    end
  end

  get "/check_pnr", to: "pnumber#check_pnr", as: :check_pnr
  get "/check_phone", to: "pnumber#check_phone", as: :check_phone

  resource :session, only: [ :create, :update ]
  get "/guest/s/default/", to: "sessions#new", as: :new_session, constraints: { format: "html" }
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
