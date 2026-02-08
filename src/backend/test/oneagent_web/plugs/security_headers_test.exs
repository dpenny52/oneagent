defmodule OneAgentWeb.Plugs.SecurityHeadersTest do
  use OneAgentWeb.ConnCase, async: true

  setup :register_and_log_in_user

  describe "security headers" do
    test "sets X-Content-Type-Options on all responses", %{conn: conn} do
      conn = get(conn, "/api/agents")
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "sets X-Frame-Options on all responses", %{conn: conn} do
      conn = get(conn, "/api/agents")
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
    end

    test "sets Referrer-Policy on all responses", %{conn: conn} do
      conn = get(conn, "/api/agents")
      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]
    end

    test "sets Permissions-Policy on all responses", %{conn: conn} do
      conn = get(conn, "/api/agents")
      assert get_resp_header(conn, "permissions-policy") == ["camera=(), microphone=(), geolocation=()"]
    end

    test "headers present on unauthenticated requests too" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post("/api/auth/login", %{"user" => %{"email" => "no@one.com", "password" => "wrong"}})

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]
    end

    test "does not set HSTS in dev/test (no force_ssl configured)", %{conn: conn} do
      conn = get(conn, "/api/agents")
      assert get_resp_header(conn, "strict-transport-security") == []
    end
  end
end
