class SessionsController < ApplicationController
  # The magic-link flow: enter email → server emails a signed URL → user
  # clicks → we verify the signature + expiry, find-or-create the user, sign
  # them in. Stateless: the link IS the token; no DB row to track.

  TOKEN_EXPIRY = 15.minutes
  TOKEN_PURPOSE = :magic_link

  # GET /login — email-entry form (and the dev-only test-sign-in shortcut).
  def new
    redirect_to root_path if signed_in?
  end

  # POST /login — generate a signed token, email a link to it, render the
  # "check your inbox" confirmation.
  def deliver
    email = params[:email].to_s.downcase.strip
    if email.blank? || !email.include?("@")
      flash.now[:alert] = "Enter a valid email address."
      render :new, status: :unprocessable_entity
      return
    end

    token = token_verifier.generate({ email: email }, expires_in: TOKEN_EXPIRY)
    return_to = safe_return_to_param || session[:return_to]
    url = auth_verify_url(token: token, return_to: return_to)

    MagicLinkMailer.link(email: email, token_url: url).deliver_later
    session[:pending_email] = email
    render :check_inbox
  end

  # GET /auth/verify?token=… — consume the signed token, sign the user in.
  def verify
    payload = token_verifier.verify(params[:token].to_s, purpose: nil)
    user = User.find_or_create_for_email(payload[:email] || payload["email"])
    session[:user_id] = user.id
    destination = safe_param_return_to || session.delete(:return_to) || root_path
    redirect_to destination, notice: "Signed in as #{user.email}", allow_other_host: false
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
    redirect_to login_path, alert: "That sign-in link is invalid or has expired. Request a new one."
  end

  # POST /login/dev — instant sign-in for local development only. Skipped
  # in any other environment. Lets the dev loop stay fast without checking
  # Letter Opener every time.
  def dev_sign_in
    head :forbidden and return unless Rails.env.development?
    email = (params[:email].presence || "you@example.com").downcase.strip
    user = User.find_or_create_for_email(email)
    session[:user_id] = user.id
    redirect_to session.delete(:return_to) || root_path, notice: "Signed in as #{user.email} (dev)"
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Signed out"
  end

  private

  def token_verifier
    Rails.application.message_verifier(TOKEN_PURPOSE)
  end

  # Only honor a `return_to` query param that points back to our own host —
  # guards against an open-redirect.
  def safe_param_return_to
    safe_internal_url(params[:return_to])
  end

  def safe_return_to_param
    safe_internal_url(params[:return_to])
  end

  def safe_internal_url(value)
    return nil if value.blank?
    parsed = URI.parse(value)
    return nil unless parsed.host.nil? || (parsed.host == request.host && parsed.port == request.port)
    value
  rescue URI::InvalidURIError
    nil
  end
end
