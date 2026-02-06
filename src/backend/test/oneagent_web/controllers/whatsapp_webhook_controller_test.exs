defmodule OneAgentWeb.WhatsAppWebhookControllerTest do
  use OneAgentWeb.ConnCase, async: true

  import OneAgent.WhatsAppFixtures

  describe "GET /api/webhooks/whatsapp (verification)" do
    test "returns challenge on valid verify_token", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)

      conn =
        get(conn, "/api/webhooks/whatsapp", %{
          "hub.mode" => "subscribe",
          "hub.verify_token" => channel.verify_token,
          "hub.challenge" => "challenge_123"
        })

      assert text_response(conn, 200) == "challenge_123"
    end

    test "returns 403 for invalid verify_token", %{conn: conn} do
      conn =
        get(conn, "/api/webhooks/whatsapp", %{
          "hub.mode" => "subscribe",
          "hub.verify_token" => "wrong_token",
          "hub.challenge" => "challenge_123"
        })

      assert json_response(conn, 403)["error"] == "Verification failed"
    end

    test "returns 403 for wrong mode", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)

      conn =
        get(conn, "/api/webhooks/whatsapp", %{
          "hub.mode" => "unsubscribe",
          "hub.verify_token" => channel.verify_token,
          "hub.challenge" => "challenge_123"
        })

      assert json_response(conn, 403)["error"] == "Verification failed"
    end

    test "returns 403 when no token provided", %{conn: conn} do
      conn =
        get(conn, "/api/webhooks/whatsapp", %{
          "hub.mode" => "subscribe",
          "hub.challenge" => "challenge_123"
        })

      assert json_response(conn, 403)["error"] == "Verification failed"
    end
  end

  describe "POST /api/webhooks/whatsapp (incoming messages)" do
    test "returns 200 immediately for valid payload", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)
      payload = webhook_payload(channel.phone_number_id)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/webhooks/whatsapp", payload)

      assert response(conn, 200) == "ok"
    end

    test "returns 200 for empty/status-only payload", %{conn: conn} do
      payload = %{
        "object" => "whatsapp_business_account",
        "entry" => [
          %{
            "changes" => [
              %{
                "value" => %{
                  "metadata" => %{"phone_number_id" => "nonexistent"},
                  "statuses" => [%{"status" => "delivered"}]
                }
              }
            ]
          }
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/webhooks/whatsapp", payload)

      assert response(conn, 200) == "ok"
    end

    test "returns 200 even with unknown phone_number_id", %{conn: conn} do
      payload = webhook_payload("unknown_phone_number")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/webhooks/whatsapp", payload)

      assert response(conn, 200) == "ok"
    end
  end
end
