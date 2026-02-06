defmodule OneAgent.Workers.ScheduleChecker do
  @moduledoc """
  Cron worker that runs every minute. Finds all scheduled agents
  whose cron expression matches the current time and enqueues
  ScheduledExecution jobs for each.
  """

  use Oban.Worker, queue: :default, max_attempts: 1

  alias OneAgent.Agents

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    Agents.list_scheduled_agents()
    |> Enum.filter(&cron_matches?(&1, now))
    |> Enum.each(fn agent ->
      %{agent_id: agent.id}
      |> OneAgent.Workers.ScheduledExecution.new()
      |> Oban.insert()
    end)

    :ok
  end

  defp cron_matches?(agent, now) do
    case get_in(agent.trigger_config, ["cron"]) do
      nil -> false
      cron_expr ->
        case Crontab.CronExpression.Parser.parse(cron_expr) do
          {:ok, cron} -> Crontab.DateChecker.matches_date?(cron, now)
          {:error, _} -> false
        end
    end
  end
end
