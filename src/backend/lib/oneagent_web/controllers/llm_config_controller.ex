defmodule OneAgentWeb.LlmConfigController do
  use OneAgentWeb, :controller

  alias OneAgent.Credentials

  action_fallback OneAgentWeb.FallbackController

  def index(conn, _params) do
    scope = conn.assigns.current_scope
    configs = Credentials.list_llm_configs(scope)
    render(conn, :index, configs: configs)
  end

  def create(conn, %{"llm_config" => config_params}) do
    scope = conn.assigns.current_scope

    with {:ok, config} <- Credentials.create_llm_config(scope, config_params) do
      conn
      |> put_status(:created)
      |> render(:show, llm_config: config)
    end
  end

  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, config} <- Credentials.get_llm_config(scope, id) do
      render(conn, :show, llm_config: config)
    end
  end

  def update(conn, %{"id" => id, "llm_config" => config_params}) do
    scope = conn.assigns.current_scope

    with {:ok, config} <- Credentials.get_llm_config(scope, id),
         {:ok, config} <- Credentials.update_llm_config(config, config_params) do
      render(conn, :show, llm_config: config)
    end
  end

  def delete(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, config} <- Credentials.get_llm_config(scope, id),
         {:ok, _config} <- Credentials.delete_llm_config(config) do
      send_resp(conn, :no_content, "")
    end
  end
end
