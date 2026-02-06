defmodule OneAgent.Runtime do
  @moduledoc """
  Public API for the agent runtime. Start, stop, and invoke agents.
  """

  alias OneAgent.Agents
  alias OneAgent.Runtime.{AgentSupervisor, AgentProcess}

  def start_agent(%{user: user}, agent_id) do
    with {:ok, agent} <- Agents.get_agent(%{user: user}, agent_id),
         :ok <- validate_can_start(agent),
         agent <- OneAgent.Repo.preload(agent, :llm_config),
         {:ok, _pid} <- AgentSupervisor.start_agent(agent),
         {:ok, agent} <- Agents.update_agent_status(agent, "running") do
      {:ok, agent}
    end
  end

  def stop_agent(%{user: user}, agent_id) do
    with {:ok, agent} <- Agents.get_agent(%{user: user}, agent_id),
         :ok <- AgentSupervisor.stop_agent(agent_id),
         {:ok, agent} <- Agents.update_agent_status(agent, "stopped") do
      {:ok, agent}
    else
      {:error, :not_running} ->
        with {:ok, agent} <- Agents.get_agent(%{user: user}, agent_id),
             {:ok, agent} <- Agents.update_agent_status(agent, "stopped") do
          {:ok, agent}
        end

      error -> error
    end
  end

  def invoke_agent(%{user: _user} = scope, agent_id, message, trigger \\ "manual") do
    with {:ok, _agent} <- Agents.get_agent(scope, agent_id) do
      AgentProcess.invoke(agent_id, message, trigger)
    end
  end

  defp validate_can_start(agent) do
    cond do
      agent.status == "running" and process_alive?(agent.id) ->
        {:error, :already_running}

      agent.llm_config_id == nil ->
        {:error, "Agent has no LLM configuration assigned"}

      true ->
        :ok
    end
  end

  defp process_alive?(agent_id) do
    case Registry.lookup(OneAgent.Runtime.AgentRegistry, agent_id) do
      [{pid, _}] -> Process.alive?(pid)
      [] -> false
    end
  end
end
