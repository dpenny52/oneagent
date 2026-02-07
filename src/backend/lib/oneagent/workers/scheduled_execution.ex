defmodule OneAgent.Workers.ScheduledExecution do
  @moduledoc """
  Executes a single scheduled agent run. Enqueued by ScheduleChecker
  when a schedule's cron expression matches.
  """

  use Oban.Worker,
    queue: :scheduled,
    max_attempts: 1,
    unique: [period: 60, keys: [:schedule_id]]

  alias OneAgent.{Agents, Runtime}
  alias OneAgent.Agents.AgentSchedule

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"schedule_id" => schedule_id}}) do
    with {:ok, schedule} <- get_schedule(schedule_id),
         :ok <- check_daily_limit(schedule.agent) do
      message = schedule.message || "Execute your scheduled task."
      scope = %{user: %{id: schedule.agent.user_id}}

      case Runtime.invoke_agent(scope, schedule.agent.id, message, "scheduled") do
        {:ok, _result} ->
          Agents.update_schedule_last_run(schedule)
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp get_schedule(schedule_id) do
    case OneAgent.Repo.get(AgentSchedule, schedule_id) do
      nil -> {:discard, "Schedule not found"}
      schedule ->
        schedule = OneAgent.Repo.preload(schedule, :agent)

        cond do
          !schedule.enabled -> {:discard, "Schedule disabled"}
          schedule.agent.llm_config_id == nil -> {:discard, "Agent has no LLM config"}
          true -> {:ok, schedule}
        end
    end
  end

  defp check_daily_limit(agent) do
    if Agents.count_runs_today(agent) >= agent.max_runs_per_day do
      {:discard, "Daily run limit exceeded"}
    else
      :ok
    end
  end
end
