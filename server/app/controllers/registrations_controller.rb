class RegistrationsController < ApplicationController
  # Account creation, passwordless with an email-confirmation gate:
  #   1. /signup — name + email + terms
  #   2. we create an *unconfirmed* user and email a signed confirmation link
  #   3. /confirm?token=… — verify, stamp confirmed_at, sign in
  # Sign-in itself lives in SessionsController; an account can't sign in until
  # it's confirmed (User.confirmed scope).

  # GET /signup
  def new
    redirect_to(root_path) and return if signed_in?
    @name = ""
  end

  # POST /signup
  def create
    @name = params[:name].to_s.strip
    email = params[:email].to_s.downcase.strip

    if email.blank? || !email.include?("@")
      return reject("Enter a valid email address.")
    end
    unless params[:terms] == "1"
      return reject("Please accept the terms to continue.")
    end

    user = User.find_or_initialize_for_signup(email)
    if user.confirmed?
      # Account already exists — send a sign-in link instead of a second
      # confirmation, and don't reveal that it exists beyond the inbox page.
      deliver_magic_link(email)
    else
      user.name = @name if @name.present?
      user.terms_accepted_at = Time.current
      user.save!
      deliver_confirmation(user)
    end

    session[:pending_email] = email
    render :check_inbox
  end

  # GET /confirm?token=…
  def confirm
    user = User.confirm_by_token(params[:token])
    unless user
      redirect_to signup_path, alert: "That confirmation link is invalid or has expired. Sign up again to get a new one." and return
    end

    session[:user_id] = user.id
    destination = safe_return_to(params[:return_to]) || root_path
    redirect_to destination, notice: "Welcome to Ike — your email is confirmed.", allow_other_host: false
  end

  private

  def reject(message)
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end

  def deliver_confirmation(user)
    url = confirm_email_url(token: user.confirmation_token, return_to: safe_return_to(params[:return_to]))
    RegistrationMailer.confirmation(user: user, confirm_url: url).deliver_later
  end

  def deliver_magic_link(email)
    url = auth_verify_url(token: MagicLink.generate(email), return_to: safe_return_to(params[:return_to]))
    MagicLinkMailer.link(email: email, token_url: url).deliver_later
  end
end
