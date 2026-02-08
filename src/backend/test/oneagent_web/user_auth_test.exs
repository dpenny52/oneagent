defmodule OneAgentWeb.UserAuthTest do
  use OneAgentWeb.ConnCase, async: true

  alias OneAgent.Accounts
  alias OneAgentWeb.UserAuth

  import OneAgent.AccountsFixtures

  setup %{conn: conn} do
    conn = put_req_header(conn, "accept", "application/json")
    user = confirmed_user_fixture()
    %{user: user, conn: conn}
  end

  describe "fetch_current_scope_for_api_user/2" do
    test "authenticates user from Bearer token", %{conn: conn, user: user} do
      token = Accounts.create_user_api_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> UserAuth.fetch_current_scope_for_api_user([])

      assert conn.assigns.current_scope.user.id == user.id
      assert conn.assigns.current_api_token == token
    end

    test "authenticates user from httpOnly cookie", %{conn: conn, user: user} do
      token = Accounts.create_user_api_token(user)

      conn =
        conn
        |> put_req_cookie("_oneagent_token", token)
        |> UserAuth.fetch_current_scope_for_api_user([])

      assert conn.assigns.current_scope.user.id == user.id
      assert conn.assigns.current_api_token == token
    end

    test "Bearer header takes priority over cookie", %{conn: conn, user: user} do
      bearer_token = Accounts.create_user_api_token(user)

      # Create a second user with a different token for the cookie
      other_user = confirmed_user_fixture()
      cookie_token = Accounts.create_user_api_token(other_user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{bearer_token}")
        |> put_req_cookie("_oneagent_token", cookie_token)
        |> UserAuth.fetch_current_scope_for_api_user([])

      # Should use the Bearer token (first user), not the cookie
      assert conn.assigns.current_scope.user.id == user.id
    end

    test "does not authenticate with invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")
        |> UserAuth.fetch_current_scope_for_api_user([])

      refute conn.assigns.current_scope
    end

    test "does not authenticate with invalid cookie token", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie("_oneagent_token", "invalid-token")
        |> UserAuth.fetch_current_scope_for_api_user([])

      refute conn.assigns.current_scope
    end

    test "does not authenticate without authorization header or cookie", %{conn: conn} do
      conn = UserAuth.fetch_current_scope_for_api_user(conn, [])
      refute conn.assigns.current_scope
    end
  end

  describe "require_authenticated_user/2" do
    test "halts with 401 if no user", %{conn: conn} do
      conn =
        conn
        |> assign(:current_scope, nil)
        |> UserAuth.require_authenticated_user([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body)["error"] =~ "must be logged in"
    end

    test "passes through if user is authenticated", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)

      conn =
        conn
        |> assign(:current_scope, scope)
        |> UserAuth.require_authenticated_user([])

      refute conn.halted
    end
  end

  describe "put_auth_cookie/2" do
    test "sets httpOnly cookie with token", %{conn: conn} do
      conn = UserAuth.put_auth_cookie(conn, "test-token-value")

      cookie = conn.resp_cookies["_oneagent_token"]
      assert cookie
      assert cookie.value == "test-token-value"
      assert cookie.http_only == true
      assert cookie.same_site == "Lax"
      assert cookie.path == "/"
      assert cookie.max_age == 365 * 24 * 60 * 60
    end
  end

  describe "delete_auth_cookie/1" do
    test "clears the auth cookie", %{conn: conn} do
      conn = UserAuth.delete_auth_cookie(conn)

      cookie = conn.resp_cookies["_oneagent_token"]
      assert cookie
      assert cookie.max_age == 0
    end
  end

  describe "login sets cookie" do
    test "POST /api/auth/login sets auth cookie", %{conn: conn, user: user} do
      conn =
        post(conn, "/api/auth/login", %{
          user: %{email: user.email, password: valid_user_password()}
        })

      assert json_response(conn, 200)["data"]["user"]["id"] == user.id

      cookie = conn.resp_cookies["_oneagent_token"]
      assert cookie
      assert cookie.http_only == true
      assert cookie.value != nil
      assert cookie.value != ""
    end

    test "POST /api/auth/register sets auth cookie", %{conn: conn} do
      conn =
        post(conn, "/api/auth/register", %{
          user: %{email: unique_user_email(), password: valid_user_password()}
        })

      assert json_response(conn, 201)["data"]["user"]

      cookie = conn.resp_cookies["_oneagent_token"]
      assert cookie
      assert cookie.http_only == true
    end

    test "DELETE /api/auth/logout clears auth cookie", %{conn: conn, user: user} do
      token = Accounts.create_user_api_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete("/api/auth/logout")

      assert json_response(conn, 200)["data"]["message"] =~ "Logged out"

      cookie = conn.resp_cookies["_oneagent_token"]
      assert cookie
      assert cookie.max_age == 0
    end
  end
end
