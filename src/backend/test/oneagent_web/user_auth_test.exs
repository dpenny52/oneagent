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

    test "does not authenticate with invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")
        |> UserAuth.fetch_current_scope_for_api_user([])

      refute conn.assigns.current_scope
    end

    test "does not authenticate without authorization header", %{conn: conn} do
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
end
