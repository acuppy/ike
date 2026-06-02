class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :signed_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def signed_in?
    current_user.present?
  end

  def require_authentication
    return if signed_in?

    redirect_to login_path
  end

  # Only honor a `return_to` value that points back to our own host — guards
  # against an open-redirect. Shared by the sessions and registrations flows.
  def safe_return_to(value)
    return nil if value.blank?

    parsed = URI.parse(value)
    return nil unless parsed.host.nil? || (parsed.host == request.host && parsed.port == request.port)

    value
  rescue URI::InvalidURIError
    nil
  end
end
