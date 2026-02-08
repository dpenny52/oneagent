defmodule OneAgent.Tools.ManageGoalStep do
  @moduledoc """
  Manages individual steps within a goal: add, update, complete, skip,
  reorder, remove, and manage step-linked schedules.
  """

  @behaviour OneAgent.Tools.Tool

  @impl true
  def id, do: "manage_goal_step"

  @impl true
  def name, do: "Manage Goal Step"

  @impl true
  def description do
    "Add, update, complete, skip, reorder, or remove steps in a goal. " <>
      "Also add or remove cron schedules linked to steps."
  end

  @impl true
  def bucket, do: nil

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "action" => %{
          "type" => "string",
          "enum" => ["add", "update", "complete", "skip", "reorder", "remove", "add_schedule", "remove_schedule"],
          "description" => "The action to perform on the step."
        },
        "goal_id" => %{
          "type" => "string",
          "description" => "The goal ID (required for 'add')."
        },
        "step_id" => %{
          "type" => "string",
          "description" => "The step ID (required for update/complete/skip/reorder/remove/add_schedule/remove_schedule)."
        },
        "title" => %{
          "type" => "string",
          "description" => "Step title (required for add)."
        },
        "description" => %{
          "type" => "string",
          "description" => "Step description."
        },
        "result_notes" => %{
          "type" => "string",
          "description" => "Notes about the outcome (used with complete/skip)."
        },
        "position" => %{
          "type" => "integer",
          "description" => "New position (used with reorder)."
        },
        "cron" => %{
          "type" => "string",
          "description" => "Cron expression for the schedule (used with add and add_schedule)."
        },
        "message" => %{
          "type" => "string",
          "description" => "Message for the schedule (used with add and add_schedule)."
        }
      },
      "required" => ["action"]
    }
  end

  @impl true
  def required_credential_type, do: nil

  @impl true
  def execute(%{"action" => "add"} = input, context) do
    agent = context[:agent]

    case input["goal_id"] do
      nil ->
        {:error, "goal_id is required for add"}

      goal_id ->
        with {:ok, goal} <- OneAgent.Agents.get_goal(agent, goal_id) do
          title = input["title"]

          if is_nil(title) || String.trim(title) == "" do
            {:error, "Missing required parameter: title"}
          else
            do_add_step(goal, input)
          end
        else
          {:error, :not_found} -> {:error, "Goal not found: #{goal_id}"}
        end
    end
  end

  def execute(%{"action" => action} = input, context) when action in ~w(update complete skip reorder remove add_schedule remove_schedule) do
    agent = context[:agent]

    case input["step_id"] do
      nil ->
        {:error, "step_id is required for #{action}"}

      step_id ->
        # Find the step — need to search across all goals for this agent
        case find_step(agent, step_id) do
          {:ok, step, goal} -> dispatch_action(action, step, goal, agent, input)
          {:error, :not_found} -> {:error, "Step not found: #{step_id}"}
        end
    end
  end

  def execute(%{"action" => action}, _context) do
    {:error, "Unknown action: #{action}. Use add, update, complete, skip, reorder, remove, add_schedule, or remove_schedule."}
  end

  def execute(_input, _context) do
    {:error, "Missing required parameter: action"}
  end

  # ── Add ───────────────────────────────────────────────────

  defp do_add_step(goal, input) do
    step_attrs = %{
      title: input["title"],
      description: input["description"]
    }

    cron = input["cron"]

    result =
      if cron && String.trim(cron) != "" do
        message = input["message"] || "Work on step: #{input["title"]}"
        sched_attrs = %{"cron" => cron, "message" => message}
        OneAgent.Agents.create_step_with_schedule(goal, step_attrs, sched_attrs)
      else
        OneAgent.Agents.create_goal_step(goal, step_attrs)
      end

    case result do
      {:ok, step} ->
        {:ok, %{
          "action" => "added",
          "success" => true,
          "step" => format_step(step),
          "note" => "Step added successfully. Respond with a text message — do NOT call step tools again."
        }}

      {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
        {:error, OneAgent.ChangesetErrors.format(changeset)}

      {:error, reason} ->
        {:error, "Failed to add step: #{inspect(reason)}"}
    end
  end

  # ── Dispatch ──────────────────────────────────────────────

  defp dispatch_action("update", step, _goal, _agent, input) do
    attrs =
      %{}
      |> maybe_put(:title, input["title"])
      |> maybe_put(:description, input["description"])
      |> maybe_put(:result_notes, input["result_notes"])

    case OneAgent.Agents.update_goal_step(step, attrs) do
      {:ok, updated} ->
        {:ok, %{
          "action" => "updated",
          "success" => true,
          "step" => format_step(updated),
          "note" => "Step updated successfully. Respond with a text message — do NOT call step tools again."
        }}

      {:error, changeset} ->
        {:error, OneAgent.ChangesetErrors.format(changeset)}
    end
  end

  defp dispatch_action("complete", step, _goal, _agent, input) do
    attrs = %{status: "completed", completed_at: DateTime.utc_now(:second)}
    attrs = maybe_put(attrs, :result_notes, input["result_notes"])

    case OneAgent.Agents.update_goal_step(step, attrs) do
      {:ok, updated} ->
        {:ok, %{
          "action" => "completed",
          "success" => true,
          "step" => format_step(updated),
          "note" => "Step completed. Respond with a text message — do NOT call step tools again."
        }}

      {:error, changeset} ->
        {:error, OneAgent.ChangesetErrors.format(changeset)}
    end
  end

  defp dispatch_action("skip", step, _goal, _agent, input) do
    attrs = %{status: "skipped"}
    attrs = maybe_put(attrs, :result_notes, input["result_notes"])

    case OneAgent.Agents.update_goal_step(step, attrs) do
      {:ok, updated} ->
        {:ok, %{
          "action" => "skipped",
          "success" => true,
          "step" => format_step(updated),
          "note" => "Step skipped. Respond with a text message — do NOT call step tools again."
        }}

      {:error, changeset} ->
        {:error, OneAgent.ChangesetErrors.format(changeset)}
    end
  end

  defp dispatch_action("reorder", step, _goal, _agent, input) do
    case input["position"] do
      nil ->
        {:error, "position is required for reorder"}

      position ->
        case OneAgent.Agents.update_goal_step(step, %{position: position}) do
          {:ok, updated} ->
            {:ok, %{
              "action" => "reordered",
              "success" => true,
              "step" => format_step(updated),
              "note" => "Step reordered. Respond with a text message — do NOT call step tools again."
            }}

          {:error, changeset} ->
            {:error, OneAgent.ChangesetErrors.format(changeset)}
        end
    end
  end

  defp dispatch_action("remove", step, _goal, _agent, _input) do
    case OneAgent.Agents.delete_goal_step(step) do
      {:ok, _} ->
        {:ok, %{
          "action" => "removed",
          "success" => true,
          "step_id" => step.id,
          "note" => "Step removed. Respond with a text message — do NOT call step tools again."
        }}

      {:error, reason} ->
        {:error, "Failed to remove step: #{inspect(reason)}"}
    end
  end

  defp dispatch_action("add_schedule", step, _goal, agent, input) do
    cron = input["cron"]

    if is_nil(cron) || String.trim(cron) == "" do
      {:error, "cron is required for add_schedule"}
    else
      # Remove existing schedule if present
      if step.schedule_id do
        case OneAgent.Agents.get_schedule(%OneAgent.Agents.Agent{id: agent.id}, step.schedule_id) do
          {:ok, old_sched} -> OneAgent.Agents.delete_schedule(old_sched)
          _ -> :ok
        end
      end

      message = input["message"] || "Work on step: #{step.title}"

      case OneAgent.Agents.create_schedule(%OneAgent.Agents.Agent{id: agent.id}, %{"cron" => cron, "message" => message}) do
        {:ok, schedule} ->
          {:ok, updated} = OneAgent.Agents.update_goal_step(step, %{schedule_id: schedule.id})

          {:ok, %{
            "action" => "schedule_added",
            "success" => true,
            "step" => format_step(updated),
            "schedule_id" => schedule.id,
            "note" => "Schedule linked to step. Respond with a text message — do NOT call step tools again."
          }}

        {:error, changeset} ->
          {:error, OneAgent.ChangesetErrors.format(changeset)}
      end
    end
  end

  defp dispatch_action("remove_schedule", step, _goal, agent, _input) do
    case step.schedule_id do
      nil ->
        {:error, "Step has no linked schedule"}

      schedule_id ->
        case OneAgent.Agents.get_schedule(%OneAgent.Agents.Agent{id: agent.id}, schedule_id) do
          {:ok, sched} -> OneAgent.Agents.delete_schedule(sched)
          _ -> :ok
        end

        {:ok, updated} = OneAgent.Agents.update_goal_step(step, %{schedule_id: nil})

        {:ok, %{
          "action" => "schedule_removed",
          "success" => true,
          "step" => format_step(updated),
          "note" => "Schedule unlinked and deleted. Respond with a text message — do NOT call step tools again."
        }}
    end
  end

  # ── Helpers ───────────────────────────────────────────────

  defp find_step(agent, step_id) do
    goals = OneAgent.Agents.list_goals(agent)

    Enum.find_value(goals, {:error, :not_found}, fn goal ->
      case OneAgent.Agents.get_goal_step(goal, step_id) do
        {:ok, step} -> {:ok, step, goal}
        _ -> nil
      end
    end)
  end

  defp format_step(step) do
    %{
      "id" => step.id,
      "title" => step.title,
      "description" => step.description,
      "status" => step.status,
      "position" => step.position,
      "schedule_id" => step.schedule_id,
      "result_notes" => step.result_notes
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
