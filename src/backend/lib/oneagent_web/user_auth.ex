defmodule OneAgentWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias OneAgent.Accounts
  alias OneAgent.Accounts.Scope

  @doc """
  Extracts the Bearer token from the Authorization header,
  looks up the user, and assigns `current_scope`.
  """
  def fetch_current_scope_for_api_user(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- Accounts.fetch_user_by_api_token(token) do
      conn
      |> assign(:current_scope, Scope.for_user(user))
      |> assign(:current_api_token, token)
    else
      _ -> assign(conn, :current_scope, nil)
    end
  end

  @doc """
  Halts with 401 JSON if no authenticated user.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "You must be logged in to access this resource."})
      |> halt()
    end
  end
end
