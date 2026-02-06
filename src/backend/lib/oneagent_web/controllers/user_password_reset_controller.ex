defmodule OneAgentWeb.UserPasswordResetController do
  use OneAgentWeb, :controller

  alias OneAgent.Accounts

  action_fallback OneAgentWeb.FallbackController

  @doc "POST /api/auth/forgot-password"
  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(user, fn token -> token end)
    end

    # Always return same response to prevent user enumeration
    conn
    |> put_status(:ok)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("message.json",
      message: "If the email is in our system, you will receive password reset instructions shortly."
    )
  end

  @doc "POST /api/auth/reset-password"
  def update(conn, %{"token" => token, "user" => user_params}) do
    case Accounts.get_user_by_reset_password_token(token) do
      %{} = user ->
        case Accounts.reset_user_password(user, user_params) do
          {:ok, _user} ->
            conn
            |> put_status(:ok)
            |> put_view(OneAgentWeb.AuthJSON)
            |> render("message.json", message: "Password has been reset successfully.")

          {:error, changeset} ->
            {:error, changeset}
        end

      nil ->
        conn
        |> put_status(:unauthorized)
        |> put_view(OneAgentWeb.AuthJSON)
        |> render("error.json", error: "Invalid or expired reset token")
    end
  end
end
