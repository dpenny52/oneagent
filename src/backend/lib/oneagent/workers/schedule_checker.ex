defmodule OneAgent.Workers.ScheduleChecker do
  @moduledoc """
  Cron worker that runs every minute. Finds all enabled schedules
  whose cron expression matches the current time and enqueues
  ScheduledExecution jobs for each.
  """

  use Oban.Worker, queue: :default, max_attempts: 1

  alias OneAgent.Agents

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    Agents.list_enabled_schedules()
    |> Enum.filter(&cron_matches?(&1, now))
    |> Enum.each(fn schedule ->
      %{schedule_id: schedule.id}
      |> OneAgent.Workers.ScheduledExecution.new()
      |> Oban.insert()
    end)

    :ok
  end

  defp cron_matches?(schedule, now) do
    case Crontab.CronExpression.Parser.parse(schedule.cron) do
      {:ok, cron} -> Crontab.DateChecker.matches_date?(cron, now)
      {:error, _} -> false
    end
  end
end
