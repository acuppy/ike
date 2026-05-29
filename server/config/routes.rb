Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # --- Authentication -------------------------------------------------------
  get "login" => "sessions#new", as: :login
  delete "logout" => "sessions#destroy", as: :logout
  match "/auth/:provider/callback" => "sessions#create", via: [:get, :post]
  get "/auth/failure" => "sessions#failure"

  # --- Device connect (custom URL scheme handoff) ---------------------------
  get "connect" => "connect#show", as: :connect

  # --- Web UI ---------------------------------------------------------------
  get "today" => "dashboard#show", as: :today
  get "week" => "weeks#show", as: :week
  get "month" => "months#show", as: :month
  resources :blocks, only: [:index, :edit, :update, :destroy]

  # --- JSON API (for the macOS widget and future iOS app) -------------------
  namespace :api do
    namespace :v1 do
      get "me" => "sessions#show"
      resources :blocks, only: [:index, :create, :update, :destroy]
    end
  end

  root "dashboard#show"
end
