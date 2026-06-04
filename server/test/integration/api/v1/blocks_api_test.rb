require "test_helper"

class Api::V1::BlocksApiTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_or_create_for_email("api@example.com")
    @other = User.find_or_create_for_email("other@example.com")
  end

  # --- Authentication / security -------------------------------------------

  test "rejects requests with no token" do
    get "/api/v1/blocks"
    assert_response :unauthorized
  end

  test "rejects an unknown token" do
    get "/api/v1/blocks", headers: bearer("nope-not-a-token")
    assert_response :unauthorized
  end

  test "rejects a valid token belonging to an unconfirmed account" do
    pending = User.find_or_initialize_for_signup("pending@example.com")
    pending.save!

    get "/api/v1/blocks", headers: bearer(pending.api_token)
    assert_response :unauthorized
  end

  # --- Per-user isolation ---------------------------------------------------

  test "index returns only the caller's blocks" do
    create_block(@user, external_id: "mine")
    create_block(@other, external_id: "theirs")

    get "/api/v1/blocks", headers: bearer(@user.api_token)

    assert_response :success
    ids = response.parsed_body.map { |b| b["external_id"] }
    assert_equal ["mine"], ids
  end

  test "cannot update another user's block" do
    theirs = create_block(@other, note: "theirs")

    patch "/api/v1/blocks/#{theirs.id}",
          params: { block: { note: "hijacked" } },
          headers: bearer(@user.api_token)

    assert_response :not_found
    assert_equal "theirs", theirs.reload.note
  end

  test "cannot destroy another user's block" do
    theirs = create_block(@other)

    assert_no_difference "Block.count" do
      delete "/api/v1/blocks/#{theirs.id}", headers: bearer(@user.api_token)
    end
    assert_response :not_found
  end

  # --- CRUD behavior --------------------------------------------------------

  test "creates a block for the caller" do
    assert_difference "@user.blocks.count", 1 do
      post "/api/v1/blocks", params: { block: valid_block_params }, headers: bearer(@user.api_token)
    end
    assert_response :created
    assert_equal "q1", response.parsed_body["quadrant"]
  end

  test "create is idempotent on external_id (retry-safe)" do
    params = { block: valid_block_params.merge(external_id: "stable-1") }

    post "/api/v1/blocks", params: params, headers: bearer(@user.api_token)
    assert_response :created

    assert_no_difference "Block.count" do
      post "/api/v1/blocks", params: params, headers: bearer(@user.api_token)
    end
    assert_response :ok
  end

  test "create rejects an invalid quadrant" do
    bad = valid_block_params.merge(quadrant: "q9")
    post "/api/v1/blocks", params: { block: bad }, headers: bearer(@user.api_token)
    assert_response :unprocessable_entity
  end

  test "updates the caller's own block" do
    block = create_block(@user, note: "before")

    patch "/api/v1/blocks/#{block.id}",
          params: { block: { note: "after" } },
          headers: bearer(@user.api_token)

    assert_response :success
    assert_equal "after", block.reload.note
  end

  test "destroys the caller's own block" do
    block = create_block(@user)

    assert_difference "@user.blocks.count", -1 do
      delete "/api/v1/blocks/#{block.id}", headers: bearer(@user.api_token)
    end
    assert_response :no_content
  end

  private

  def bearer(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def valid_block_params
    {
      starts_at: "2026-06-02T09:00:00Z",
      ends_at: "2026-06-02T09:10:00Z",
      quadrant: "q1",
      note: "writing tests",
      auto: false
    }
  end

  def create_block(user, external_id: nil, note: "")
    user.blocks.create!(
      starts_at: Time.utc(2026, 6, 2, 9, 0),
      ends_at: Time.utc(2026, 6, 2, 9, 10),
      quadrant: "q1",
      note: note,
      external_id: external_id
    )
  end
end
