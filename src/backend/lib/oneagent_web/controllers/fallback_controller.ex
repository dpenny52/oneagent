defmodule OneAgentWeb.FallbackController do
  use OneAgentWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("error.json", error: "Not found")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("error.json", error: "Invalid credentials")
  end

  def call(conn, {:error, :registration_disabled}) do
    conn
    |> put_status(:forbidden)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("error.json", error: "Registration is not available at this time")
  end

  def call(conn, {:error, message}) when is_binary(message) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("error.json", error: message)
  end

  def call(conn, {:error, reason}) when is_atom(reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("error.json", error: reason |> Atom.to_string() |> String.replace("_", " "))
  end
end
