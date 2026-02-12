defmodule OneAgentWeb.FallbackController do
  use OneAgentWeb, :controller
  require Logger

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)

    Logger.warning("Fallback: changeset error on #{conn.method} #{conn.request_path} — #{inspect(errors)}")

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    Logger.warning("Fallback: not_found on #{conn.method} #{conn.request_path}")

    conn
    |> put_status(:not_found)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("error.json", error: "Not found")
  end

  def call(conn, {:error, :unauthorized}) do
    Logger.warning("Fallback: unauthorized on #{conn.method} #{conn.request_path}")

    conn
    |> put_status(:unauthorized)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("error.json", error: "Invalid credentials")
  end

  def call(conn, {:error, :registration_disabled}) do
    Logger.warning("Fallback: registration_disabled on #{conn.method} #{conn.request_path}")

    conn
    |> put_status(:forbidden)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("error.json", error: "Registration is not available at this time")
  end

  def call(conn, {:error, message}) when is_binary(message) do
    Logger.warning("Fallback: error on #{conn.method} #{conn.request_path} — #{message}")

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("error.json", error: message)
  end

  def call(conn, {:error, reason}) when is_atom(reason) do
    Logger.warning("Fallback: #{reason} on #{conn.method} #{conn.request_path}")

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(OneAgentWeb.AuthJSON)
    |> render("error.json", error: reason |> Atom.to_string() |> String.replace("_", " "))
  end
end
