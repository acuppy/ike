# Hands the signed-in user's API token back to a desktop / mobile client via
# a custom URL scheme. Flow:
#   1. The macOS widget opens GET /connect?return_scheme=ike in the browser.
#   2. If not signed in, we bounce through /login (magic link) carrying this
#      URL as return_to so we land back here after sign-in.
#   3. We render an HTML page with an "Open Ike" button (plain anchor to
#      the ike:// URL). The user click is what hands off to the OS — a
#      direct user-initiated navigation gets handled by every browser,
#      while a server-side 302 to a non-http scheme gets silently dropped
#      by Safari and modern Chrome.
class ConnectController < ApplicationController
  ALLOWED_SCHEMES = %w[ike].freeze

  def show
    scheme = params[:return_scheme].to_s
    unless ALLOWED_SCHEMES.include?(scheme)
      render plain: "Unsupported return_scheme", status: :bad_request
      return
    end

    unless signed_in?
      redirect_to login_path(return_to: request.url)
      return
    end

    @app_url = "#{scheme}://connected?token=#{CGI.escape(current_user.api_token)}&email=#{CGI.escape(current_user.email)}"
    render :show
  end
end
