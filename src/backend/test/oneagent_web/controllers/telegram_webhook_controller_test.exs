defmodule OneAgentWeb.TelegramWebhookControllerTest do
  use OneAgentWeb.ConnCase, async: true

  import OneAgent.TelegramFixtures

  describe "POST /api/webhooks/telegram/:bot_id" do
    test "returns 200 with valid secret token header", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)
      payload = webhook_payload()

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-telegram-bot-api-secret-token", channel.secret_token)
        |> post("/api/webhooks/telegram/#{channel.bot_id}", payload)

      assert response(conn, 200) == "ok"
    end

    test "returns 200 with invalid secret token (silent rejection)", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)
      payload = webhook_payload()

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-telegram-bot-api-secret-token", "wrong_token")
        |> post("/api/webhooks/telegram/#{channel.bot_id}", payload)

      assert response(conn, 200) == "ok"
    end

    test "returns 200 with missing secret token header (silent rejection)", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)
      payload = webhook_payload()

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/webhooks/telegram/#{channel.bot_id}", payload)

      assert response(conn, 200) == "ok"
    end

    test "returns 200 for unknown bot_id (silent)", %{conn: conn} do
      payload = webhook_payload()

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/webhooks/telegram/unknown_bot_id", payload)

      assert response(conn, 200) == "ok"
    end

    test "returns 200 for non-message updates (e.g., edited_message)", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)

      # edited_message payload (no "message" key)
      payload = %{
        "update_id" => 123,
        "edited_message" => %{
          "message_id" => 456,
          "chat" => %{"id" => 789, "type" => "private"},
          "text" => "edited text"
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-telegram-bot-api-secret-token", channel.secret_token)
        |> post("/api/webhooks/telegram/#{channel.bot_id}", payload)

      assert response(conn, 200) == "ok"
    end

    test "returns 200 for callback_query updates", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)

      payload = %{
        "update_id" => 123,
        "callback_query" => %{
          "id" => "abc",
          "from" => %{"id" => 789},
          "data" => "button_click"
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-telegram-bot-api-secret-token", channel.secret_token)
        |> post("/api/webhooks/telegram/#{channel.bot_id}", payload)

      assert response(conn, 200) == "ok"
    end

    test "auto-captures owner_chat_id on first message", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)

      # Verify channel starts with nil owner_chat_id
      assert channel.owner_chat_id == nil

      chat_id = 99999
      payload = webhook_payload(chat_id, "Hello")

      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-telegram-bot-api-secret-token", channel.secret_token)
      |> post("/api/webhooks/telegram/#{channel.bot_id}", payload)

      # Give async task time to process
      Process.sleep(100)

      # Reload channel and verify owner_chat_id was captured
      updated = OneAgent.Repo.get!(OneAgent.Telegram.Channel, channel.id)
      assert updated.owner_chat_id == "99999"
    end

    test "does not overwrite existing owner_chat_id", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)

      # Manually set owner_chat_id
      {:ok, channel} = OneAgent.Telegram.update_channel_unscoped(channel, %{owner_chat_id: "11111"})
      assert channel.owner_chat_id == "11111"

      # Send message from a different chat_id
      payload = webhook_payload(22222, "Hello from someone else")

      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-telegram-bot-api-secret-token", channel.secret_token)
      |> post("/api/webhooks/telegram/#{channel.bot_id}", payload)

      # Give async task time to process
      Process.sleep(100)

      # Verify owner_chat_id was NOT overwritten
      updated = OneAgent.Repo.get!(OneAgent.Telegram.Channel, channel.id)
      assert updated.owner_chat_id == "11111"
    end
  end
end
