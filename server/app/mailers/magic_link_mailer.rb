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
end
