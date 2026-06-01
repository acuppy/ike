# Hands the signed-in user's API token back to a desktop / mobile client via
# a custom URL scheme. Flow:
#   1. The macOS widget opens GET /connect?return_scheme=ike in the browser.
#   2. If not signed in, we bounce through /login (magic link) carrying this
#      URL as return_to so we land back here after sign-in.
#   3. We redirect to ike://connected?token=…&email=…, which macOS routes
#      to the app (registered in Info.plist).
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

    redirect_to "#{scheme}://connected?token=#{CGI.escape(current_user.api_token)}&email=#{CGI.escape(current_user.email)}",
                allow_other_host: true
  end
end
