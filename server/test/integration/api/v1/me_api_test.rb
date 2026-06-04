require "test_helper"

class Api::V1::MeApiTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get "/api/v1/me"
    assert_response :unauthorized
  end

  test "returns the authenticated user" do
    user = User.find_or_create_for_email("me@example.com")
    user.update!(name: "Ada")

    get "/api/v1/me", headers: { "Authorization" => "Bearer #{user.api_token}" }

    assert_response :success
    body = response.parsed_body
    assert_equal user.id, body["id"]
    assert_equal "me@example.com", body["email"]
    assert_equal "Ada", body["name"]
  end
end
