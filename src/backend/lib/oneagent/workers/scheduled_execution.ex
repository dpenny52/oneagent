defmodule OneAgent.Workers.ScheduledExecution do
  @moduledoc """
  Executes a single scheduled agent run. Enqueued by ScheduleChecker
  when an agent's cron expression matches.
  """

  use Oban.Worker,
    queue: :scheduled,
    max_attempts: 1,
    unique: [period: 60, keys: [:agent_id]]

  alias OneAgent.{Agents, Runtime}
  alias OneAgent.Runtime.AgentSupervisor

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"agent_id" => agent_id}}) do
    with {:ok, agent} <- get_running_scheduled_agent(agent_id),
         :ok <- check_daily_limit(agent),
         :ok <- ensure_process_alive(agent) do
      message = get_in(agent.trigger_config, ["message"]) || "Execute your scheduled task."

      # Build a scope from the agent's owner for authorization
      scope = %{user: %{id: agent.user_id}}

      case Runtime.invoke_agent(scope, agent_id, message, "scheduled") do
        {:ok, _result} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp get_running_scheduled_agent(agent_id) do
    case OneAgent.Repo.get(Agents.Agent, agent_id) do
      nil -> {:error, :not_found}
      %{status: status} when status != "running" -> {:discard, "Agent not running"}
      %{trigger_type: trigger} when trigger != "scheduled" -> {:discard, "Agent not scheduled"}
      agent -> {:ok, agent}
    end
  end

  defp check_daily_limit(agent) do
    if Agents.count_runs_today(agent) >= agent.max_runs_per_day do
      {:discard, "Daily run limit exceeded"}
    else
      :ok
    end
  end

  defp ensure_process_alive(agent) do
    case Registry.lookup(OneAgent.Runtime.AgentRegistry, agent.id) do
      [{pid, _}] when is_pid(pid) ->
        if Process.alive?(pid), do: :ok, else: restart_process(agent)
      [] ->
        restart_process(agent)
    end
  end

  defp restart_process(agent) do
    agent = OneAgent.Repo.preload(agent, :llm_config)

    case AgentSupervisor.start_agent(agent) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, "Failed to start agent process: #{inspect(reason)}"}
    end
  end
end
