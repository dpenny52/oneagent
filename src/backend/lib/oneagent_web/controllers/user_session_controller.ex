defmodule OneAgentWeb.UserSessionController do
  use OneAgentWeb, :controller

  alias OneAgent.Accounts

  action_fallback OneAgentWeb.FallbackController

  @doc "POST /api/auth/login — email/password login"
  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %{} = user ->
        token = Accounts.create_user_api_token(user)

        conn
        |> put_status(:ok)
        |> put_view(OneAgentWeb.AuthJSON)
        |> render("user.json", user: user, token: token)

      nil ->
        # Same shape response to prevent user enumeration
        conn
        |> put_status(:unauthorized)
        |> put_view(OneAgentWeb.AuthJSON)
        |> render("error.json", error: "Invalid email or password")
    end
  end

  @doc "POST /api/auth/magic-link — request a magic link email"
  def send_magic_link(conn, %{"user" => %{"email" => email}}) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_magic_link(user, fn token -> token end)
    end

    # Always return same response to prevent user enumeration
    conn
    |> put_status(:ok)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("message.json", message: "If the email is in our system, you will receive a magic link shortly.")
  end

  @doc "POST /api/auth/magic-link/verify — verify magic link token, return API token"
  def verify_magic_link(conn, %{"token" => token}) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, _expired_tokens}} ->
        api_token = Accounts.create_user_api_token(user)

        conn
        |> put_status(:ok)
        |> put_view(OneAgentWeb.AuthJSON)
        |> render("user.json", user: user, token: api_token)

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> put_view(OneAgentWeb.AuthJSON)
        |> render("error.json", error: "Invalid or expired magic link")
    end
  end

  @doc "DELETE /api/auth/logout — revoke current API token"
  def delete(conn, _params) do
    token = conn.assigns[:current_api_token]
    if token, do: Accounts.delete_user_api_token(token)

    conn
    |> put_status(:ok)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("message.json", message: "Logged out successfully.")
  end

  @doc "GET /api/auth/me — get current user"
  def me(conn, _params) do
    user = conn.assigns.current_scope.user

    conn
    |> put_status(:ok)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("user.json", user: user)
  end

  @doc "PUT /api/auth/password — change password (authenticated)"
  def update_password(conn, %{"current_password" => current_password, "user" => user_params}) do
    user = conn.assigns.current_scope.user

    if OneAgent.Accounts.User.valid_password?(user, current_password) do
      case Accounts.update_user_password(user, user_params) do
        {:ok, {updated_user, _expired_tokens}} ->
          new_token = Accounts.create_user_api_token(updated_user)

          conn
          |> put_status(:ok)
          |> put_view(OneAgentWeb.AuthJSON)
          |> render("user.json", user: updated_user, token: new_token)

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      conn
      |> put_status(:unauthorized)
      |> put_view(OneAgentWeb.AuthJSON)
      |> render("error.json", error: "Current password is incorrect")
    end
  end
end
