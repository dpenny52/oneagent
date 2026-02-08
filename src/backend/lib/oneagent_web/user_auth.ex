defmodule OneAgentWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias OneAgent.Accounts
  alias OneAgent.Accounts.Scope

  @auth_cookie "_oneagent_token"
  # 365 days in seconds, matching API token validity
  @max_age 365 * 24 * 60 * 60

  @doc """
  Extracts the API token from the Authorization header or httpOnly cookie,
  looks up the user, and assigns `current_scope`.

  Bearer header takes priority (for programmatic API clients).
  Cookie is used as fallback (for browser-based frontend).
  """
  def fetch_current_scope_for_api_user(conn, _opts) do
    token = extract_bearer_token(conn) || extract_cookie_token(conn)

    case token do
      nil ->
        assign(conn, :current_scope, nil)

      token ->
        case Accounts.fetch_user_by_api_token(token) do
          {:ok, user} ->
            conn
            |> assign(:current_scope, Scope.for_user(user))
            |> assign(:current_api_token, token)

          _ ->
            assign(conn, :current_scope, nil)
        end
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

  @doc """
  Sets an httpOnly, Secure cookie with the API token.
  Uses SameSite=None on prod (cross-site frontend/backend), Lax in dev.
  """
  def put_auth_cookie(conn, token) do
    secure = secure_cookie?()

    conn
    |> put_resp_cookie(@auth_cookie, token,
      http_only: true,
      secure: secure,
      same_site: if(secure, do: "None", else: "Lax"),
      max_age: @max_age,
      path: "/"
    )
  end

  @doc """
  Clears the auth cookie on logout.
  """
  def delete_auth_cookie(conn) do
    conn
    |> delete_resp_cookie(@auth_cookie, path: "/")
  end

  defp extract_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end

  defp extract_cookie_token(conn) do
    conn = fetch_cookies(conn)
    conn.cookies[@auth_cookie]
  end

  defp secure_cookie? do
    Application.get_env(:oneagent, OneAgentWeb.Endpoint)[:url][:scheme] == "https"
  end
end
