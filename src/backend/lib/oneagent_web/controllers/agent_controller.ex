defmodule OneAgentWeb.AgentController do
  use OneAgentWeb, :controller

  alias OneAgent.{Agents, Runtime}

  action_fallback OneAgentWeb.FallbackController

  def index(conn, _params) do
    scope = conn.assigns.current_scope
    agents = Agents.list_agents(scope)
    render(conn, :index, agents: agents)
  end

  def create(conn, %{"agent" => agent_params}) do
    scope = conn.assigns.current_scope

    with {:ok, agent} <- Agents.create_agent(scope, agent_params) do
      conn
      |> put_status(:created)
      |> render(:show, agent: agent)
    end
  end

  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, agent} <- Agents.get_agent(scope, id) do
      render(conn, :show, agent: agent)
    end
  end

  def update(conn, %{"id" => id, "agent" => agent_params}) do
    scope = conn.assigns.current_scope

    with {:ok, agent} <- Agents.get_agent(scope, id),
         {:ok, agent} <- Agents.update_agent(agent, agent_params) do
      render(conn, :show, agent: agent)
    end
  end

  def delete(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, agent} <- Agents.get_agent(scope, id),
         {:ok, _agent} <- Agents.delete_agent(agent) do
      send_resp(conn, :no_content, "")
    end
  end

  # ── Lifecycle ────────────────────────────────────────────────

  def start(conn, %{"agent_id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, agent} <- Runtime.start_agent(scope, id) do
      render(conn, :show, agent: agent)
    end
  end

  def stop(conn, %{"agent_id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, agent} <- Runtime.stop_agent(scope, id) do
      render(conn, :show, agent: agent)
    end
  end

  def invoke(conn, %{"agent_id" => id, "message" => message}) do
    scope = conn.assigns.current_scope
    trigger = conn.params["trigger"] || "manual"

    with {:ok, result} <- Runtime.invoke_agent(scope, id, message, trigger) do
      render(conn, :invoke, result: result)
    end
  end

  # ── Buckets ──────────────────────────────────────────────────

  def list_buckets(conn, %{"agent_id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, agent} <- Agents.get_agent(scope, id) do
      buckets = Agents.list_active_buckets(agent)
      render(conn, :buckets, buckets: buckets)
    end
  end

  def update_buckets(conn, %{"agent_id" => id, "buckets" => bucket_configs}) do
    scope = conn.assigns.current_scope

    with {:ok, agent} <- Agents.get_agent(scope, id),
         {:ok, buckets} <- Agents.update_buckets(agent, atomize_bucket_configs(bucket_configs)) do
      render(conn, :buckets, buckets: buckets)
    end
  end

  # ── Runs ─────────────────────────────────────────────────────

  def list_runs(conn, %{"agent_id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, agent} <- Agents.get_agent(scope, id) do
      runs = Agents.list_runs(agent)
      render(conn, :runs, runs: runs)
    end
  end

  def show_run(conn, %{"agent_id" => agent_id, "id" => run_id}) do
    scope = conn.assigns.current_scope

    with {:ok, agent} <- Agents.get_agent(scope, agent_id),
         {:ok, run} <- Agents.get_run_with_steps(agent, run_id) do
      render(conn, :run, run: run)
    end
  end

  # ── Memory ───────────────────────────────────────────────────

  def list_memories(conn, %{"agent_id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, agent} <- Agents.get_agent(scope, id) do
      memories = Agents.list_memories(agent)
      render(conn, :memories, memories: memories)
    end
  end

  def delete_memories(conn, %{"agent_id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, agent} <- Agents.get_agent(scope, id) do
      Agents.delete_all_memories(agent)
      send_resp(conn, :no_content, "")
    end
  end

  defp atomize_bucket_configs(configs) when is_list(configs) do
    Enum.map(configs, fn config ->
      config
      |> Map.take(["bucket", "scope_config", "credential_id"])
      |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)
    end)
  end
end
