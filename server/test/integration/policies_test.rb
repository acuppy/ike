require "test_helper"

class PoliciesTest < ActionDispatch::IntegrationTest
  test "terms page renders publicly" do
    get terms_path
    assert_response :success
    assert_select "h1", "Terms of Service"
  end

  test "privacy page renders publicly" do
    get privacy_path
    assert_response :success
    assert_select "h1", "Privacy Policy"
  end
end
