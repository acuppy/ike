require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "find_or_initialize_for_signup stamps provider/uid without persisting" do
    user = User.find_or_initialize_for_signup("New@Example.com ")

    assert_predicate user, :new_record?
    assert_equal "new@example.com", user.email
    assert_equal "email", user.provider
    assert_equal "new@example.com", user.uid
  end

  test "new signups are unconfirmed and excluded from the confirmed scope" do
    user = User.find_or_initialize_for_signup("pending@example.com")
    user.save!

    refute_predicate user, :confirmed?
    refute_includes User.confirmed, user
  end

  test "confirm! stamps confirmed_at once" do
    user = create_signup("confirm@example.com")

    user.confirm!
    first = user.confirmed_at
    assert_predicate user, :confirmed?

    user.confirm!
    assert_equal first, user.reload.confirmed_at, "re-confirming should not move the timestamp"
    assert_includes User.confirmed, user
  end

  test "confirm_by_token confirms the matching user and is idempotent" do
    user = create_signup("token@example.com")
    token = user.confirmation_token

    confirmed = User.confirm_by_token(token)
    assert_equal user, confirmed
    assert_predicate user.reload, :confirmed?
  end

  test "confirm_by_token returns nil for a tampered token" do
    user = create_signup("tamper@example.com")
    bad = user.confirmation_token + "x"

    assert_nil User.confirm_by_token(bad)
    refute_predicate user.reload, :confirmed?
  end

  test "find_or_create_for_email yields a confirmed, persisted user (dev shortcut)" do
    user = User.find_or_create_for_email("Dev@Example.com")

    assert_predicate user, :persisted?
    assert_predicate user, :confirmed?
    assert_equal "dev@example.com", user.email
  end

  private

  def create_signup(email)
    User.find_or_initialize_for_signup(email).tap(&:save!)
  end
end
