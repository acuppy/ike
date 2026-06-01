class User < ApplicationRecord
  has_many :blocks, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :provider, :uid, presence: true
  validates :api_token, presence: true, uniqueness: true

  before_validation :ensure_api_token, on: :create

  # Find or create a user by verified email. The "verified" part comes from
  # the magic-link flow — we only call this after consuming a valid signed
  # token that proves the user controls the inbox. provider/uid linger from
  # the OmniAuth era; we just stamp them with "email" so the columns aren't
  # null. No migration needed.
  def self.find_or_create_for_email(email)
    user = find_or_initialize_by(email: email.to_s.downcase.strip)
    user.provider = "email"
    user.uid = user.email
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
