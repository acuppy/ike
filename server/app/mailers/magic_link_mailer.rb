class MagicLinkMailer < ApplicationMailer
  # `email` — the address the link is being sent to. Used in the subject /
  # body for clarity if the user has multiple addresses.
  # `token_url` — fully-qualified URL with the signed magic-link token. The
  # SessionsController builds this so the mailer doesn't have to know the
  # token format.
  def link(email:, token_url:)
    @email = email
    @token_url = token_url
    mail(to: email, subject: "Sign in to Ike")
  end

  # Sent when someone tries to sign in with an email that has no account.
  # Pairs with the non-enumerating "check your inbox" page so the sign-in
  # form never reveals whether an address is registered.
  def no_account(email:, signup_url:)
    @email = email
    @signup_url = signup_url
    mail(to: email, subject: "Create your Ike account")
  end
end
