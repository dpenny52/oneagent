defmodule OneAgentWeb.CredentialController do
  use OneAgentWeb, :controller

  alias OneAgent.Credentials

  action_fallback OneAgentWeb.FallbackController

  # ── Credentials ──────────────────────────────────────────────

  def index(conn, _params) do
    scope = conn.assigns.current_scope
    credentials = Credentials.list_credentials(scope)
    render(conn, :index, credentials: credentials)
  end

  def create(conn, %{"credential" => cred_params}) do
    scope = conn.assigns.current_scope

    with {:ok, credential} <- Credentials.create_credential(scope, cred_params) do
      conn
      |> put_status(:created)
      |> render(:show, credential: credential)
    end
  end

  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, credential} <- Credentials.get_credential(scope, id) do
      render(conn, :show, credential: credential)
    end
  end

  def update(conn, %{"id" => id, "credential" => cred_params}) do
    scope = conn.assigns.current_scope

    with {:ok, credential} <- Credentials.get_credential(scope, id),
         {:ok, credential} <- Credentials.update_credential(credential, cred_params) do
      render(conn, :show, credential: credential)
    end
  end

  def delete(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, credential} <- Credentials.get_credential(scope, id),
         {:ok, _cred} <- Credentials.delete_credential(credential) do
      send_resp(conn, :no_content, "")
    end
  end
end
