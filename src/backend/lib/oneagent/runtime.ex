defmodule OneAgent.Runtime do
  @moduledoc """
  Public API for the agent runtime. Invoke agents with auto-start.
  """

  alias OneAgent.Agents
  alias OneAgent.Runtime.{AgentSupervisor, AgentProcess}

  def invoke_agent(%{user: _user} = scope, agent_id, message, trigger \\ "manual", opts \\ %{}) do
    with {:ok, agent} <- Agents.get_agent(scope, agent_id),
         :ok <- validate_has_llm_config(agent),
         :ok <- ensure_process_running(agent) do
      AgentProcess.invoke(agent_id, message, trigger, opts)
    end
  end

  defp validate_has_llm_config(agent) do
    if agent.llm_config_id == nil do
      {:error, "Agent has no LLM configuration assigned"}
    else
      :ok
    end
  end

  defp ensure_process_running(agent) do
    case Registry.lookup(OneAgent.Runtime.AgentRegistry, agent.id) do
      [{pid, _}] ->
        if Process.alive?(pid), do: :ok, else: start_process(agent)
      [] ->
        start_process(agent)
    end
  end

  defp start_process(agent) do
    agent = OneAgent.Repo.preload(agent, :llm_config)

    case AgentSupervisor.start_agent(agent) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, "Failed to start agent process: #{inspect(reason)}"}
    end
  end
end
