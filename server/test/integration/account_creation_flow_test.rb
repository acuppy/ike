require "test_helper"

class AccountCreationFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "signup creates an unconfirmed user and emails a confirmation link" do
    mail = nil
    assert_difference "User.count", 1 do
      perform_enqueued_jobs do
        post signup_create_path, params: { name: "Ada", email: "Ada@Example.com", terms: "1" }
      end
    end
    mail = ActionMailer::Base.deliveries.last

    user = User.find_by(email: "ada@example.com")
    assert_equal "Ada", user.name
    assert_not_nil user.terms_accepted_at
    refute_predicate user, :confirmed?
    assert_nil session[:user_id], "signup must not sign the user in before confirmation"
    assert_equal "Confirm your email for Ike", mail.subject
    assert_equal ["ada@example.com"], mail.to
    assert_response :success
  end

  test "signup without accepting terms is rejected and creates no user" do
    assert_no_difference "User.count" do
      post signup_create_path, params: { name: "Ada", email: "ada@example.com", terms: "0" }
    end
    assert_response :unprocessable_entity
  end

  test "confirming the emailed token activates the account and signs in" do
    post signup_create_path, params: { email: "confirm@example.com", terms: "1" }
    user = User.find_by(email: "confirm@example.com")

    get confirm_email_path(token: user.confirmation_token)

    assert_predicate user.reload, :confirmed?
    assert_equal user.id, session[:user_id]
    assert_redirected_to root_path
  end

  test "a bad confirmation token bounces back to signup" do
    get confirm_email_path(token: "not-a-real-token")
    assert_redirected_to signup_path
  end

  test "signing up with an already-confirmed email sends a sign-in link instead" do
    User.find_or_create_for_email("existing@example.com") # confirmed

    assert_no_difference "User.count" do
      perform_enqueued_jobs do
        post signup_create_path, params: { email: "existing@example.com", terms: "1" }
      end
    end
    assert_equal "Sign in to Ike", ActionMailer::Base.deliveries.last.subject
    assert_response :success
  end
end
