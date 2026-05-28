class User < ApplicationRecord
  has_many :blocks, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :provider, :uid, presence: true
  validates :api_token, presence: true, uniqueness: true

  before_validation :ensure_api_token, on: :create

  # Find or create a user from an OmniAuth callback hash. We dedupe by email
  # so the same identity can switch between providers (e.g. signing in via
  # the dev login first, then later linking the real Google account) without
  # leaving orphaned records behind. In production only Google sign-in is
  # configured, and Google verifies the email — so trusting email is safe.
  def self.from_omniauth(auth)
    user = find_or_initialize_by(email: auth.info.email)
    user.provider = auth.provider
    user.uid = auth.uid
    user.name = auth.info.name
    user.avatar_url = auth.info.image
    user.save!
    user
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
