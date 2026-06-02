Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # --- Authentication (magic link) ------------------------------------------
  get "login" => "sessions#new", as: :login
  post "login" => "sessions#deliver", as: :login_deliver
  get "auth/verify" => "sessions#verify", as: :auth_verify
  delete "logout" => "sessions#destroy", as: :logout

  # --- Account creation (email confirmation) --------------------------------
  get "signup" => "registrations#new", as: :signup
  post "signup" => "registrations#create", as: :signup_create
  get "confirm" => "registrations#confirm", as: :confirm_email

  # --- Legal -----------------------------------------------------------------
  get "terms" => "policies#terms", as: :terms
  get "privacy" => "policies#privacy", as: :privacy
  if Rails.env.development?
    # Dev-only instant sign-in for fast local testing. Disabled outside dev.
    post "login/dev" => "sessions#dev_sign_in", as: :login_dev
  end

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
