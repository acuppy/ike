class SessionsController < ApplicationController
  # Sign-in for existing, confirmed accounts. Enter email → we email a signed
  # link → click → verify + sign in. Account *creation* lives in
  # RegistrationsController; this flow never creates a user.

  # GET /login — email-entry form (and the dev-only test-sign-in shortcut).
  def new
    redirect_to root_path if signed_in?
  end

  # POST /login — email a link, then render the (non-enumerating) "check your
  # inbox" page. What we send depends on the account, but the page never says:
  #   - confirmed account  → magic-link sign-in
  #   - unconfirmed account → resend the confirmation link
  #   - no account          → a "create one" nudge
  def deliver
    email = params[:email].to_s.downcase.strip
    if email.blank? || !email.include?("@")
      flash.now[:alert] = "Enter a valid email address."
      render :new, status: :unprocessable_entity
      return
    end

    return_to = safe_return_to(params[:return_to]) || session[:return_to]
    user = User.find_by(email: email)

    if user&.confirmed?
      url = auth_verify_url(token: MagicLink.generate(email), return_to: return_to)
      MagicLinkMailer.link(email: email, token_url: url).deliver_later
    elsif user
      url = confirm_email_url(token: user.confirmation_token, return_to: return_to)
      RegistrationMailer.confirmation(user: user, confirm_url: url).deliver_later
    else
      MagicLinkMailer.no_account(email: email, signup_url: signup_url(return_to: return_to)).deliver_later
    end

    session[:pending_email] = email
    render :check_inbox
  end

  # GET /auth/verify?token=… — consume the signed token, sign the user in.
  # Only confirmed accounts ever receive a magic link, so an unknown email
  # here means a stale link from before the account existed — send to signup.
  def verify
    email = MagicLink.email_from(params[:token])
    user = User.confirmed.find_by(email: email)
    unless user
      redirect_to signup_path, alert: "Finish creating your account to sign in." and return
    end

    session[:user_id] = user.id
    destination = safe_return_to(params[:return_to]) || session.delete(:return_to) || root_path
    redirect_to destination, notice: "Signed in as #{user.email}", allow_other_host: false
  rescue MagicLink::InvalidToken
    redirect_to login_path, alert: "That sign-in link is invalid or has expired. Request a new one."
  end

  # POST /login/dev — instant sign-in for local development only.
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
end
