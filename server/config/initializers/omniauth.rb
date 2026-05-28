Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV["GOOGLE_CLIENT_ID"],
           ENV["GOOGLE_CLIENT_SECRET"],
           scope: "email,profile",
           prompt: "select_account"

  # In development you can sign in without configuring Google by visiting
  # /auth/developer. Never enabled outside development.
  if Rails.env.development?
    provider :developer, fields: [:name, :email], uid_field: :email
  end
end

OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.silence_get_warning = true
