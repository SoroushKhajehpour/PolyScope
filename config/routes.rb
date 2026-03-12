Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker


  root "markets#index"

  resources :markets, only: [:show], param: :event_id do
    member do
      get :score_result
    end

    collection do
      get :live_search
    end
  end

  if Rails.env.development?
    get "dev/api_diagnostics", to: "dev_diagnostics#api"
  end

  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

end
