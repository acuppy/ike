class RegistrationMailer < ApplicationMailer
  # `user` — the freshly-signed-up (unconfirmed) account.
  # `confirm_url` — fully-qualified URL with the signed confirmation token.
  # The controller builds the URL so the mailer stays out of the token format.
  def confirmation(user:, confirm_url:)
    @user = user
    @confirm_url = confirm_url
    mail(to: user.email, subject: "Confirm your email for Ike")
  end
end
