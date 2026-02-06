defmodule OneAgentWeb.UserConfirmationController do
  use OneAgentWeb, :controller

  alias OneAgent.Accounts

  action_fallback OneAgentWeb.FallbackController

  @doc "POST /api/auth/confirm — resend confirmation email (authenticated)"
  def create(conn, _params) do
    user = conn.assigns.current_scope && conn.assigns.current_scope.user

    if user do
      case Accounts.deliver_user_confirmation_instructions(user, fn token -> token end) do
        {:ok, _email} ->
          conn
          |> put_status(:ok)
          |> put_view(OneAgentWeb.AuthJSON)
          |> render("message.json", message: "If your email is not confirmed, you will receive confirmation instructions shortly.")

        {:error, :already_confirmed} ->
          conn
          |> put_status(:ok)
          |> put_view(OneAgentWeb.AuthJSON)
          |> render("message.json", message: "Account is already confirmed.")
      end
    else
      conn
      |> put_status(:unauthorized)
      |> put_view(OneAgentWeb.AuthJSON)
      |> render("error.json", error: "You must be logged in to resend confirmation.")
    end
  end

  @doc "POST /api/auth/confirm/:token — confirm account with token"
  def confirm(conn, %{"token" => token}) do
    case Accounts.confirm_user(token) do
      {:ok, _user} ->
        conn
        |> put_status(:ok)
        |> put_view(OneAgentWeb.AuthJSON)
        |> render("message.json", message: "Account confirmed successfully.")

      :error ->
        conn
        |> put_status(:unauthorized)
        |> put_view(OneAgentWeb.AuthJSON)
        |> render("error.json", error: "Invalid or expired confirmation token")
    end
  end
end
