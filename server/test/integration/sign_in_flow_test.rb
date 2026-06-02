require "test_helper"

class SignInFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "confirmed account gets a magic-link sign-in email" do
    User.find_or_create_for_email("member@example.com")

    perform_enqueued_jobs do
      post login_deliver_path, params: { email: "member@example.com" }
    end

    assert_equal "Sign in to Ike", ActionMailer::Base.deliveries.last.subject
    assert_response :success
  end

  test "unknown email gets a non-enumerating 'create account' email and no user" do
    assert_no_difference "User.count" do
      perform_enqueued_jobs do
        post login_deliver_path, params: { email: "stranger@example.com" }
      end
    end

    assert_equal "Create your Ike account", ActionMailer::Base.deliveries.last.subject
    assert_response :success
  end

  test "unconfirmed account gets the confirmation link resent on sign-in attempt" do
    User.find_or_initialize_for_signup("pending@example.com").save!

    perform_enqueued_jobs do
      post login_deliver_path, params: { email: "pending@example.com" }
    end

    assert_equal "Confirm your email for Ike", ActionMailer::Base.deliveries.last.subject
    assert_response :success
  end

  test "verifying a magic link signs in a confirmed user" do
    User.find_or_create_for_email("verify@example.com")
    token = MagicLink.generate("verify@example.com")

    get auth_verify_path(token: token)

    assert_redirected_to root_path
    assert_not_nil session[:user_id]
  end

  test "a magic link for an unconfirmed email routes to signup" do
    User.find_or_initialize_for_signup("notyet@example.com").save!
    token = MagicLink.generate("notyet@example.com")

    get auth_verify_path(token: token)

    assert_redirected_to signup_path
    assert_nil session[:user_id]
  end
end
