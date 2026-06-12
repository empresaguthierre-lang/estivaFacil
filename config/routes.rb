Rails.application.routes.draw do
  root "dashboard#index"

  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :session, only: [ :new, :create, :destroy ]
  resources :cargos, only: [ :index, :show, :new, :create, :edit, :update ] do
    post :duplicate, on: :member
  end
  resources :products
  resources :package_boxes
  resources :vehicles
  resources :stowage_plans, only: [ :show ]
end
