defmodule OneAgentWeb.WhatsAppChannelControllerTest do
  use OneAgentWeb.ConnCase, async: true

  import OneAgent.WhatsAppFixtures

  setup :register_and_log_in_user

  describe "GET /api/whatsapp-channels" do
    test "lists channels for authenticated user", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      _channel = channel_fixture(scope)

      conn = get(conn, "/api/whatsapp-channels")
      assert %{"data" => [channel_data]} = json_response(conn, 200)
      assert channel_data["phone_number_id"] != nil
      # verify_token is NOT included in list responses
      refute Map.has_key?(channel_data, "verify_token")
    end

    test "does not list other users' channels", %{conn: conn} do
      other_scope = scope_fixture()
      _channel = channel_fixture(other_scope)

      conn = get(conn, "/api/whatsapp-channels")
      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "POST /api/whatsapp-channels" do
    test "creates a channel and returns verify_token", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      attrs = valid_channel_attributes(scope)

      conn = post(conn, "/api/whatsapp-channels", %{"channel" => attrs})
      assert %{"data" => data} = json_response(conn, 201)
      assert data["phone_number_id"] == attrs["phone_number_id"]
      # verify_token IS included in create response
      assert is_binary(data["verify_token"])
    end

    test "rejects if agent not owned by user", %{conn: conn} do
      other_scope = scope_fixture()
      other_attrs = valid_channel_attributes(other_scope)

      conn = post(conn, "/api/whatsapp-channels", %{"channel" => other_attrs})
      assert json_response(conn, 422)
    end
  end

  describe "GET /api/whatsapp-channels/:id" do
    test "shows a channel without verify_token", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      channel = channel_fixture(scope)

      conn = get(conn, "/api/whatsapp-channels/#{channel.id}")
      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == channel.id
      refute Map.has_key?(data, "verify_token")
    end

    test "returns 404 for other user's channel", %{conn: conn} do
      other_scope = scope_fixture()
      channel = channel_fixture(other_scope)

      conn = get(conn, "/api/whatsapp-channels/#{channel.id}")
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/whatsapp-channels/:id" do
    test "updates channel fields", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      channel = channel_fixture(scope)

      conn =
        put(conn, "/api/whatsapp-channels/#{channel.id}", %{
          "channel" => %{"active" => false, "display_phone_number" => "+9999999999"}
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["active"] == false
      assert data["display_phone_number"] == "+9999999999"
    end
  end

  describe "DELETE /api/whatsapp-channels/:id" do
    test "deletes a channel", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      channel = channel_fixture(scope)

      conn = delete(conn, "/api/whatsapp-channels/#{channel.id}")
      assert response(conn, 204)
    end

    test "returns 404 for other user's channel", %{conn: conn} do
      other_scope = scope_fixture()
      channel = channel_fixture(other_scope)

      conn = delete(conn, "/api/whatsapp-channels/#{channel.id}")
      assert json_response(conn, 404)
    end
  end
end
