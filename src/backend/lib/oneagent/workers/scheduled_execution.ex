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
  alias OneAgent.Accounts.Scope
  alias OneAgent.Agents.AgentSchedule

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"schedule_id" => schedule_id}}) do
    with {:ok, schedule} <- get_schedule(schedule_id),
         :ok <- check_daily_limit(schedule.agent) do
      message = schedule.message || "Execute your scheduled task."
      message = enrich_with_goal_context(message, schedule_id)
      scope = Scope.for_user(schedule.agent.user)

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
        schedule = OneAgent.Repo.preload(schedule, agent: :user)

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

  # Enrich the schedule message with goal context if the schedule
  # is linked to a goal step or is a goal review schedule.
  defp enrich_with_goal_context(message, schedule_id) do
    cond do
      # Check if schedule is linked to a goal step
      step = Agents.get_step_by_schedule(schedule_id) ->
        goal = step.goal
        message <>
          "\n\n[Schedule context: This schedule is linked to goal \"#{goal.title}\" " <>
          "(goal_id: #{goal.id}), step: \"#{step.title}\" " <>
          "(step_id: #{step.id}, status: #{step.status}). Focus on advancing this step.]"

      # Check if schedule is a goal review schedule
      goal = Agents.get_goal_by_review_schedule(schedule_id) ->
        message <>
          "\n\n[Goal review: You are reviewing goal \"#{goal.title}\" " <>
          "(goal_id: #{goal.id}). Check your steps, update statuses, " <>
          "create/modify/remove step schedules as needed, and take the next appropriate action.]"

      # No goal context
      true ->
        message
    end
  end
end
