require "test_helper"

class WebSecurityTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  # --- Authentication gating ------------------------------------------------

  test "protected pages redirect to login when signed out" do
    [today_path, week_path, month_path, blocks_path].each do |path|
      get path
      assert_redirected_to login_path, "#{path} should require sign-in"
    end
  end

  test "the connect handoff requires sign-in" do
    get connect_path(return_scheme: "ike")
    assert_response :redirect
    assert_no_match %r{\Aike://}, @response.location.to_s
  end

  # --- Open-redirect guard --------------------------------------------------

  test "magic-link verify ignores an external return_to" do
    User.find_or_create_for_email("safe@example.com")
    token = MagicLink.generate("safe@example.com")

    get auth_verify_path(token: token, return_to: "http://evil.example.com/steal")

    assert_equal session[:user_id], User.find_by(email: "safe@example.com").id
    assert_redirected_to root_path # not the external host
  end

  test "confirmation ignores an external return_to" do
    user = User.find_or_initialize_for_signup("confirmsafe@example.com")
    user.save!

    get confirm_email_path(token: user.confirmation_token, return_to: "https://evil.example.com")

    assert_redirected_to root_path
  end

  # --- Token expiry ---------------------------------------------------------

  test "an expired confirmation token is rejected" do
    user = User.find_or_initialize_for_signup("expired@example.com")
    user.save!
    token = user.confirmation_token

    travel (User::CONFIRMATION_EXPIRY + 1.hour) do
      get confirm_email_path(token: token)
    end

    assert_redirected_to signup_path
    refute_predicate user.reload, :confirmed?
  end

  test "an expired magic link is rejected" do
    User.find_or_create_for_email("stalelink@example.com")
    token = MagicLink.generate("stalelink@example.com")

    travel (MagicLink::EXPIRY + 1.minute) do
      get auth_verify_path(token: token)
    end

    assert_redirected_to login_path
    assert_nil session[:user_id]
  end
end
