class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Ike <ike@localhost>")
  layout "mailer"
end
