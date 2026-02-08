defmodule OneAgent.Tools.ListGoals do
  @moduledoc """
  Lists the agent's goals with step progress and schedule info.
  No permission bucket required — goals are internal to the agent.
  """

  @behaviour OneAgent.Tools.Tool

  @impl true
  def id, do: "list_goals"

  @impl true
  def name, do: "List Goals"

  @impl true
  def description do
    "List your goals with step progress. Returns active goals by default, or all goals if active_only is false. " <>
      "Provide goal_id to see detailed information about a single goal."
  end

  @impl true
  def bucket, do: nil

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "active_only" => %{
          "type" => "boolean",
          "description" => "If true (default), only return active goals. Set to false to include completed/paused/abandoned."
        },
        "goal_id" => %{
          "type" => "string",
          "description" => "Get detailed information about a specific goal."
        }
      },
      "required" => []
    }
  end

  @impl true
  def required_credential_type, do: nil

  @impl true
  def execute(input, context) do
    agent = context[:agent]

    case input["goal_id"] do
      nil ->
        list_goals(agent, input)

      goal_id ->
        case OneAgent.Agents.get_goal(agent, goal_id) do
          {:ok, goal} ->
            {:ok, %{"goal" => format_goal_detail(goal)}}

          {:error, :not_found} ->
            {:error, "Goal not found: #{goal_id}"}
        end
    end
  end

  defp list_goals(agent, input) do
    active_only = input["active_only"] != false

    opts = if active_only, do: [status: "active"], else: []
    goals = OneAgent.Agents.list_goals(agent, opts)

    items = Enum.map(goals, &format_goal_summary/1)

    {:ok, %{"goals" => items, "count" => length(items)}}
  end

  defp format_goal_summary(goal) do
    steps = goal.steps || []
    completed = Enum.count(steps, &(&1.status == "completed"))
    total = length(steps)

    %{
      "id" => goal.id,
      "title" => goal.title,
      "status" => goal.status,
      "priority" => goal.priority,
      "progress" => "#{completed}/#{total}",
      "review_schedule_id" => goal.review_schedule_id,
      "due_date" => goal.due_date && DateTime.to_iso8601(goal.due_date)
    }
  end

  defp format_goal_detail(goal) do
    steps = goal.steps || []
    completed = Enum.count(steps, &(&1.status == "completed"))

    review_cron =
      case goal.review_schedule do
        %{cron: cron} -> cron
        _ -> nil
      end

    %{
      "id" => goal.id,
      "title" => goal.title,
      "description" => goal.description,
      "status" => goal.status,
      "priority" => goal.priority,
      "progress" => "#{completed}/#{length(steps)}",
      "due_date" => goal.due_date && DateTime.to_iso8601(goal.due_date),
      "review_schedule_id" => goal.review_schedule_id,
      "review_cron" => review_cron,
      "steps" => Enum.map(steps, fn s ->
        %{
          "id" => s.id,
          "title" => s.title,
          "description" => s.description,
          "status" => s.status,
          "position" => s.position,
          "schedule_id" => s.schedule_id,
          "result_notes" => s.result_notes
        }
      end)
    }
  end
end
