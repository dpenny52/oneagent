defmodule OneAgentWeb.CalendarAuthController do
  use OneAgentWeb, :controller

  alias OneAgent.Credentials

  @token_url "https://oauth2.googleapis.com/token"
  @auth_url "https://accounts.google.com/o/oauth2/v2/auth"
  @scope "https://www.googleapis.com/auth/calendar.events"

  @doc """
  Returns a Google OAuth URL for Calendar authorization.
  The frontend navigates the user to this URL.
  """
  def authorize(conn, _params) do
    user = conn.assigns.current_scope.user
    state = Phoenix.Token.sign(conn, "calendar_oauth", user.id)

    redirect_uri = calendar_redirect_uri()
    client_id = calendar_client_id()

    url =
      @auth_url <>
        "?" <>
        URI.encode_query(%{
          client_id: client_id,
          redirect_uri: redirect_uri,
          response_type: "code",
          scope: @scope,
          access_type: "offline",
          prompt: "consent",
          state: state
        })

    json(conn, %{data: %{url: url}})
  end

  @doc """
  Handles the OAuth callback from Google. Exchanges the code for tokens,
  stores the refresh_token as a credential, and redirects to the frontend.
  """
  def callback(conn, %{"error" => error}) do
    redirect(conn, external: frontend_url() <> "/keys?calendar_error=" <> URI.encode(error))
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    with {:ok, user_id} <- Phoenix.Token.verify(conn, "calendar_oauth", state, max_age: 600),
         {:ok, user} <- fetch_user(user_id),
         {:ok, refresh_token} <- exchange_code(code) do
      scope = OneAgent.Accounts.Scope.for_user(user)
      upsert_calendar_credential(scope, refresh_token)
      redirect(conn, external: frontend_url() <> "/keys?calendar_connected=true")
    else
      {:error, reason} when is_binary(reason) ->
        redirect(conn, external: frontend_url() <> "/keys?calendar_error=" <> URI.encode(reason))

      {:error, _} ->
        redirect(conn, external: frontend_url() <> "/keys?calendar_error=invalid_state")
    end
  end

  def callback(conn, _params) do
    redirect(conn, external: frontend_url() <> "/keys?calendar_error=missing_code")
  end

  # ── Private helpers ──

  defp exchange_code(code) do
    body = %{
      code: code,
      client_id: calendar_client_id(),
      client_secret: calendar_client_secret(),
      redirect_uri: calendar_redirect_uri(),
      grant_type: "authorization_code"
    }

    case Req.post(@token_url, form: body) do
      {:ok, %{status: 200, body: %{"refresh_token" => refresh_token}}} ->
        {:ok, refresh_token}

      {:ok, %{status: 200, body: _body}} ->
        {:error, "no_refresh_token"}

      {:ok, %{body: %{"error_description" => desc}}} ->
        {:error, desc}

      {:ok, %{status: status}} ->
        {:error, "token_exchange_failed_#{status}"}

      {:error, _} ->
        {:error, "token_exchange_request_failed"}
    end
  end

  defp upsert_calendar_credential(scope, refresh_token) do
    value = Jason.encode!(%{"refresh_token" => refresh_token})
    attrs = %{"name" => "Google Calendar", "service" => "google_calendar", "credential_type" => "oauth_token", "value" => value}

    case find_calendar_credential(scope) do
      nil -> Credentials.create_credential(scope, attrs)
      existing -> Credentials.update_credential(existing, %{"value" => value})
    end
  end

  defp find_calendar_credential(%{user: user}) do
    import Ecto.Query

    OneAgent.Credentials.Credential
    |> where(user_id: ^user.id, service: "google_calendar")
    |> OneAgent.Repo.one()
  end

  defp fetch_user(user_id) do
    case OneAgent.Repo.get(OneAgent.Accounts.User, user_id) do
      nil -> {:error, "user_not_found"}
      user -> {:ok, user}
    end
  end

  defp calendar_client_id do
    Application.get_env(:oneagent, :google_calendar_client_id)
  end

  defp calendar_client_secret do
    Application.get_env(:oneagent, :google_calendar_client_secret)
  end

  defp calendar_redirect_uri do
    host = Application.get_env(:oneagent, OneAgentWeb.Endpoint)[:url][:host]

    if host && host != "localhost" do
      "https://#{host}/api/auth/calendar/callback"
    else
      port = Application.get_env(:oneagent, OneAgentWeb.Endpoint)[:http][:port] || 4000
      "http://localhost:#{port}/api/auth/calendar/callback"
    end
  end

  defp frontend_url do
    Application.get_env(:oneagent, :frontend_url, "http://localhost:3000")
  end
end
