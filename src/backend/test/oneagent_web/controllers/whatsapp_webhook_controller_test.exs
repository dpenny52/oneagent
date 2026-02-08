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

    test "returns 403 when challenge contains HTML/script injection", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)

      conn =
        get(conn, "/api/webhooks/whatsapp", %{
          "hub.mode" => "subscribe",
          "hub.verify_token" => channel.verify_token,
          "hub.challenge" => "<script>alert('xss')</script>"
        })

      assert json_response(conn, 403)["error"] == "Verification failed"
    end

    test "returns 403 when challenge is empty string", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)

      conn =
        get(conn, "/api/webhooks/whatsapp", %{
          "hub.mode" => "subscribe",
          "hub.verify_token" => channel.verify_token,
          "hub.challenge" => ""
        })

      assert json_response(conn, 403)["error"] == "Verification failed"
    end

    test "returns 403 when challenge is missing", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)

      conn =
        get(conn, "/api/webhooks/whatsapp", %{
          "hub.mode" => "subscribe",
          "hub.verify_token" => channel.verify_token
        })

      assert json_response(conn, 403)["error"] == "Verification failed"
    end

    test "returns 403 when challenge exceeds max length", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)

      conn =
        get(conn, "/api/webhooks/whatsapp", %{
          "hub.mode" => "subscribe",
          "hub.verify_token" => channel.verify_token,
          "hub.challenge" => String.duplicate("a", 257)
        })

      assert json_response(conn, 403)["error"] == "Verification failed"
    end

    test "accepts challenge with hyphens and underscores", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)

      conn =
        get(conn, "/api/webhooks/whatsapp", %{
          "hub.mode" => "subscribe",
          "hub.verify_token" => channel.verify_token,
          "hub.challenge" => "challenge-token_2024"
        })

      assert text_response(conn, 200) == "challenge-token_2024"
    end
  end

  describe "POST /api/webhooks/whatsapp (incoming messages)" do
    test "returns 200 with valid HMAC signature", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)
      payload = webhook_payload(channel.phone_number_id)
      # Encode to JSON string — this is the exact body that will be sent and captured by CacheRawBody
      json_body = Jason.encode!(payload)
      signature = compute_signature(json_body, "test_app_secret_123")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-hub-signature-256", signature)
        |> post("/api/webhooks/whatsapp", json_body)

      assert response(conn, 200) == "ok"
    end

    test "returns 403 with invalid HMAC signature", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)
      payload = webhook_payload(channel.phone_number_id)
      json_body = Jason.encode!(payload)
      signature = compute_signature(json_body, "wrong_secret")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-hub-signature-256", signature)
        |> post("/api/webhooks/whatsapp", json_body)

      assert json_response(conn, 403)["error"] == "Invalid signature"
    end

    test "returns 403 with missing HMAC signature", %{conn: conn} do
      scope = scope_fixture()
      channel = channel_fixture(scope)
      payload = webhook_payload(channel.phone_number_id)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/webhooks/whatsapp", Jason.encode!(payload))

      assert json_response(conn, 403)["error"] == "Invalid signature"
    end

    test "returns 403 for unknown phone_number_id (no channel)", %{conn: conn} do
      payload = webhook_payload("unknown_phone_number")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/webhooks/whatsapp", payload)

      assert json_response(conn, 403)["error"] == "Invalid signature"
    end

    test "returns 200 for empty/status-only payload (no messages)", %{conn: conn} do
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
  end
end
