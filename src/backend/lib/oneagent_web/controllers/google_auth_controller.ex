defmodule OneAgentWeb.GoogleAuthController do
  use OneAgentWeb, :controller

  plug Ueberauth

  alias OneAgent.Accounts
  import OneAgentWeb.UserAuth, only: [put_auth_cookie: 2]

  def request(conn, _params) do
    # Ueberauth handles the redirect automatically via the plug
    conn
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Accounts.find_or_create_google_user(auth) do
      {:ok, user} ->
        token = Accounts.create_user_api_token(user)

        conn
        |> put_auth_cookie(token)
        |> put_status(:ok)
        |> put_view(OneAgentWeb.AuthJSON)
        |> render("user.json", user: user, token: token)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(OneAgentWeb.AuthJSON)
        |> render("error.json", changeset: changeset)
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    conn
    |> put_status(:unauthorized)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("error.json", error: "Google authentication failed")
  end
end
