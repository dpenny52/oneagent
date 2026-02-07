defmodule OneAgentWeb.UserRegistrationController do
  use OneAgentWeb, :controller

  alias OneAgent.Accounts

  action_fallback OneAgentWeb.FallbackController

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        token = Accounts.create_user_api_token(user)

        conn
        |> put_status(:created)
        |> put_view(OneAgentWeb.AuthJSON)
        |> render("user.json", user: user, token: token)

      {:error, :registration_disabled} ->
        conn
        |> put_status(:forbidden)
        |> put_view(OneAgentWeb.AuthJSON)
        |> render("error.json", error: "Registration is not available at this time")

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
