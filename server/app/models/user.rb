class User < ApplicationRecord
  CONFIRMATION_PURPOSE = :email_confirmation
  CONFIRMATION_EXPIRY = 24.hours

  has_many :blocks, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :provider, :uid, presence: true
  validates :api_token, presence: true, uniqueness: true

  before_validation :ensure_api_token, on: :create

  # A user can't sign in until they've confirmed their email. Confirmation
  # proof is the signed token we mail at signup; the timestamp records the
  # click. Existing users were grandfathered in the migration.
  scope :confirmed, -> { where.not(confirmed_at: nil) }

  # Build (unsaved) or find a user for the signup flow, stamping the
  # legacy provider/uid columns so the caller only has to set name + terms.
  def self.find_or_initialize_for_signup(email)
    find_or_initialize_by(email: email.to_s.downcase.strip).tap do |user|
      user.provider = "email"
      user.uid = user.email
    end
  end

  # Find or create an already-confirmed user from a trusted email. Only used
  # by the dev-only instant sign-in — the real flows go through signup +
  # confirmation. provider/uid linger from the OmniAuth era.
  def self.find_or_create_for_email(email)
    find_or_initialize_for_signup(email).tap do |user|
      user.confirmed_at ||= Time.current
      user.save!
    end
  end

  # Verify a confirmation token and confirm the matching user, returning it.
  # Returns nil on a bad or expired token.
  def self.confirm_by_token(token)
    id = confirmation_verifier.verify(token.to_s)
    find_by(id: id)&.tap(&:confirm!)
  rescue ActiveSupport::MessageVerifier::InvalidSignature,
         ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def self.confirmation_verifier
    Rails.application.message_verifier(CONFIRMATION_PURPOSE)
  end

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current) unless confirmed?
  end

  # Signed, expiring token proving the holder controls this account's inbox.
  # Stateless — no DB column — mirroring the magic-link approach.
  def confirmation_token
    self.class.confirmation_verifier.generate(id, expires_in: CONFIRMATION_EXPIRY)
  end

  def rotate_api_token!
    update!(api_token: self.class.generate_api_token)
  end

  def self.generate_api_token
    SecureRandom.urlsafe_base64(32)
  end

  private

  def ensure_api_token
    self.api_token ||= self.class.generate_api_token
  end
end
