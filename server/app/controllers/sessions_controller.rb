class SessionsController < ApplicationController
  # OmniAuth verifies the callback itself (OAuth state / its own CSRF token on
  # the request phase), so Rails' form-based forgery check doesn't apply here.
  skip_forgery_protection only: :create

  # OmniAuth handles the redirect to Google; this is the callback target.
  def create
    user = User.from_omniauth(request.env["omniauth.auth"])
    session[:user_id] = user.id
    destination = safe_return_to || root_path
    redirect_to destination, notice: "Signed in as #{user.email}"
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Signed out"
  end

  def failure
    redirect_to login_path, alert: "Sign in failed: #{params[:message]}"
  end

  # The login screen with the "Sign in with Google" button.
  def new
    redirect_to root_path if signed_in?
  end

  private

  # Only honor a return_to that we put in the session and that points back to
  # our own host — guards against an open-redirect via tampered session data.
  def safe_return_to
    url = session.delete(:return_to)
    return nil if url.blank?

    parsed = URI.parse(url)
    return nil unless parsed.host == request.host && parsed.port == request.port
    url
  rescue URI::InvalidURIError
    nil
  end
end
