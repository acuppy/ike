# Stateless sign-in token shared by the sessions and registrations flows.
# The signed payload IS the token — no DB row — so any controller that needs
# to mint or read a sign-in link goes through here rather than reaching into
# Rails.application.message_verifier directly.
class MagicLink
  PURPOSE = :magic_link
  EXPIRY = 15.minutes

  InvalidToken = Class.new(StandardError)

  # Returns the verified email, or raises InvalidToken if the signature is
  # bad or the link has expired.
  def self.email_from(token)
    payload = verifier.verify(token.to_s, purpose: nil)
    payload[:email] || payload["email"]
  rescue ActiveSupport::MessageVerifier::InvalidSignature,
         ActiveSupport::MessageEncryptor::InvalidMessage
    raise InvalidToken
  end

  def self.generate(email)
    verifier.generate({ email: email }, expires_in: EXPIRY)
  end

  def self.verifier
    Rails.application.message_verifier(PURPOSE)
  end
end
