defmodule OneAgentWeb.GmailAuthControllerTest do
  use OneAgentWeb.ConnCase, async: true

  setup :register_and_log_in_user

  describe "GET /api/auth/gmail" do
    test "returns Google OAuth URL when authenticated", %{conn: conn} do
      conn = get(conn, "/api/auth/gmail")
      assert %{"data" => %{"url" => url}} = json_response(conn, 200)
      assert url =~ "accounts.google.com"
      assert url =~ "gmail.readonly"
      assert url =~ "state="
    end

    test "rejects unauthenticated requests" do
      conn = build_conn() |> put_req_header("accept", "application/json")
      conn = get(conn, "/api/auth/gmail")
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/auth/gmail/callback" do
    test "redirects with error for invalid state", %{conn: conn} do
      conn = get(conn, "/api/auth/gmail/callback", %{"code" => "fake_code", "state" => "invalid"})
      assert redirected_to(conn) =~ "/keys?gmail_error="
    end

    test "redirects with error when error param present", %{conn: conn} do
      conn = get(conn, "/api/auth/gmail/callback", %{"error" => "access_denied"})
      assert redirected_to(conn) =~ "/keys?gmail_error=access_denied"
    end

    test "redirects with error when no code or error", %{conn: conn} do
      conn = get(conn, "/api/auth/gmail/callback")
      assert redirected_to(conn) =~ "/keys?gmail_error=missing_code"
    end
  end
end
