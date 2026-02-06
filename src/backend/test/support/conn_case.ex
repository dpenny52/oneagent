defmodule OneAgentWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint OneAgentWeb.Endpoint

      use OneAgentWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import OneAgentWeb.ConnCase
    end
  end

  setup tags do
    OneAgent.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users via API token.

      setup :register_and_log_in_user
  """
  def register_and_log_in_user(%{conn: conn}) do
    user = OneAgent.AccountsFixtures.confirmed_user_fixture()
    token = OneAgent.Accounts.create_user_api_token(user)

    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
      |> Plug.Conn.put_req_header("accept", "application/json")

    %{conn: conn, user: user, token: token}
  end

  @doc """
  Adds Bearer token auth header to a conn for an existing user.
  """
  def authenticate_user(conn, user) do
    token = OneAgent.Accounts.create_user_api_token(user)

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
    |> Plug.Conn.put_req_header("accept", "application/json")
  end
end
