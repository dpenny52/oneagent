defmodule OneAgent.Tools.ManageGoal do
  @moduledoc """
  Creates, updates, and manages agent goals with optional inline step creation.
  No permission bucket required — goals are internal to the agent.
  """

  @behaviour OneAgent.Tools.Tool

  @max_active_goals_per_agent 20

  @impl true
  def id, do: "manage_goal"

  @impl true
  def name, do: "Manage Goal"

  @impl true
  def description do
    "Create, update, complete, pause, resume, abandon, or delete a goal. " <>
      "Goals track multi-step objectives. When creating, provide steps with optional cron schedules. " <>
      "Each goal gets an automatic hourly review schedule."
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
          "enum" => ["create", "update", "complete", "pause", "resume", "abandon", "delete"],
          "description" => "The action to perform on the goal."
        },
        "goal_id" => %{
          "type" => "string",
          "description" => "The goal ID (required for update/complete/pause/resume/abandon/delete)."
        },
        "title" => %{
          "type" => "string",
          "description" => "Goal title (required for create)."
        },
        "description" => %{
          "type" => "string",
          "description" => "Goal description. Optional."
        },
        "priority" => %{
          "type" => "integer",
          "description" => "Priority level (higher = more important). Default 0."
        },
        "due_date" => %{
          "type" => "string",
          "description" => "Due date in ISO 8601 format (e.g. '2024-03-15T09:00:00Z'). Optional."
        },
        "steps" => %{
          "type" => "array",
          "description" => "Steps to create with the goal. Each step can include a cron schedule.",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "title" => %{"type" => "string", "description" => "Step title (required)"},
              "description" => %{"type" => "string", "description" => "Step description"},
              "cron" => %{"type" => "string", "description" => "Cron expression for recurring execution of this step"},
              "message" => %{"type" => "string", "description" => "Message for the cron schedule (defaults to 'Work on step: [title]')"}
            },
            "required" => ["title"]
          }
        }
      },
      "required" => ["action"]
    }
  end

  @impl true
  def required_credential_type, do: nil

  @impl true
  def execute(%{"action" => "create"} = input, context) do
    agent = context[:agent]
    title = input["title"]

    cond do
      is_nil(title) || String.trim(title) == "" ->
        {:error, "Missing required parameter: title"}

      OneAgent.Agents.count_goals(agent, "active") >= @max_active_goals_per_agent ->
        {:error, "Active goal limit reached (maximum #{@max_active_goals_per_agent} per agent). Complete, abandon, or delete existing goals before creating new ones."}

      true ->
        do_create(agent, input)
    end
  end

  def execute(%{"action" => action} = input, context) when action in ~w(update complete pause resume abandon delete) do
    agent = context[:agent]

    case input["goal_id"] do
      nil ->
        {:error, "goal_id is required for #{action}"}

      goal_id ->
        case OneAgent.Agents.get_goal(agent, goal_id) do
          {:ok, goal} -> dispatch_action(action, goal, input)
          {:error, :not_found} -> {:error, "Goal not found: #{goal_id}"}
        end
    end
  end

  def execute(%{"action" => action}, _context) do
    {:error, "Unknown action: #{action}. Use create, update, complete, pause, resume, abandon, or delete."}
  end

  def execute(_input, _context) do
    {:error, "Missing required parameter: action"}
  end

  # ── Create ────────────────────────────────────────────────

  defp do_create(agent, input) do
    attrs = %{
      title: input["title"],
      description: input["description"],
      priority: input["priority"] || 0
    }

    attrs = maybe_put_due_date(attrs, input["due_date"])

    case OneAgent.Agents.create_goal(agent, attrs) do
      {:ok, goal} ->
        # Create steps (with optional inline schedules)
        steps = create_steps(goal, input["steps"] || [])

        # Create auto review schedule
        review_schedule = create_review_schedule(agent, goal)

        # Link review schedule to goal
        {:ok, goal} =
          if review_schedule do
            OneAgent.Agents.update_goal(goal, %{review_schedule_id: review_schedule.id})
          else
            {:ok, goal}
          end

        # Reload with preloads
        {:ok, goal} = OneAgent.Agents.get_goal(agent, goal.id)

        {:ok, %{
          "action" => "created",
          "success" => true,
          "goal" => format_goal(goal),
          "steps_created" => length(steps),
          "review_schedule_id" => review_schedule && review_schedule.id,
          "note" => "Goal created successfully with #{length(steps)} step(s) and an automatic hourly review schedule. Respond with a text message describing your plan — do NOT call goal tools again."
        }}

      {:error, changeset} ->
        {:error, OneAgent.ChangesetErrors.format(changeset)}
    end
  end

  defp create_steps(goal, step_inputs) do
    step_inputs
    |> Enum.with_index()
    |> Enum.map(fn {step_input, _idx} ->
      step_attrs = %{
        title: step_input["title"],
        description: step_input["description"]
      }

      cron = step_input["cron"]

      if cron && String.trim(cron) != "" do
        message = step_input["message"] || "Work on step: #{step_input["title"]}"
        sched_attrs = %{"cron" => cron, "message" => message}

        case OneAgent.Agents.create_step_with_schedule(goal, step_attrs, sched_attrs) do
          {:ok, step} -> step
          {:error, _} -> nil
        end
      else
        case OneAgent.Agents.create_goal_step(goal, step_attrs) do
          {:ok, step} -> step
          {:error, _} -> nil
        end
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp create_review_schedule(agent, goal) do
    message = "Review goal: #{goal.title}. Check step progress, update statuses, adjust step schedules, and take next actions."

    case OneAgent.Agents.create_schedule(agent, %{
      "cron" => "0 * * * *",
      "message" => message
    }) do
      {:ok, schedule} -> schedule
      {:error, _} -> nil
    end
  end

  # ── Action dispatch ───────────────────────────────────────

  defp dispatch_action("update", goal, input) do
    attrs =
      %{}
      |> maybe_put(:title, input["title"])
      |> maybe_put(:description, input["description"])
      |> maybe_put(:priority, input["priority"])

    attrs = maybe_put_due_date(attrs, input["due_date"])

    case OneAgent.Agents.update_goal(goal, attrs) do
      {:ok, updated} ->
        {:ok, %{
          "action" => "updated",
          "success" => true,
          "goal" => format_goal(updated),
          "note" => "Goal updated successfully. Respond with a text message — do NOT call goal tools again."
        }}

      {:error, changeset} ->
        {:error, OneAgent.ChangesetErrors.format(changeset)}
    end
  end

  defp dispatch_action("complete", goal, _input) do
    case OneAgent.Agents.complete_goal(goal) do
      {:ok, completed} ->
        {:ok, %{
          "action" => "completed",
          "success" => true,
          "goal_id" => completed.id,
          "note" => "Goal completed. All pending steps marked as completed and schedules disabled. Respond with a text message — do NOT call goal tools again."
        }}

      {:error, reason} ->
        {:error, "Failed to complete goal: #{inspect(reason)}"}
    end
  end

  defp dispatch_action("pause", goal, _input) do
    case OneAgent.Agents.update_goal(goal, %{status: "paused"}) do
      {:ok, paused} ->
        OneAgent.Agents.disable_goal_schedules(paused)

        {:ok, %{
          "action" => "paused",
          "success" => true,
          "goal_id" => paused.id,
          "note" => "Goal paused and schedules disabled. Use 'resume' to reactivate. Respond with a text message — do NOT call goal tools again."
        }}

      {:error, changeset} ->
        {:error, OneAgent.ChangesetErrors.format(changeset)}
    end
  end

  defp dispatch_action("resume", goal, _input) do
    case OneAgent.Agents.update_goal(goal, %{status: "active"}) do
      {:ok, resumed} ->
        # Re-enable review schedule
        if resumed.review_schedule_id do
          case OneAgent.Agents.get_schedule(%OneAgent.Agents.Agent{id: resumed.agent_id}, resumed.review_schedule_id) do
            {:ok, sched} -> OneAgent.Agents.update_schedule(sched, %{"enabled" => true})
            _ -> :ok
          end
        end

        {:ok, %{
          "action" => "resumed",
          "success" => true,
          "goal_id" => resumed.id,
          "note" => "Goal resumed and review schedule re-enabled. Respond with a text message — do NOT call goal tools again."
        }}

      {:error, changeset} ->
        {:error, OneAgent.ChangesetErrors.format(changeset)}
    end
  end

  defp dispatch_action("abandon", goal, _input) do
    case OneAgent.Agents.abandon_goal(goal) do
      {:ok, abandoned} ->
        {:ok, %{
          "action" => "abandoned",
          "success" => true,
          "goal_id" => abandoned.id,
          "note" => "Goal abandoned. Pending steps marked as skipped and schedules disabled. Respond with a text message — do NOT call goal tools again."
        }}

      {:error, reason} ->
        {:error, "Failed to abandon goal: #{inspect(reason)}"}
    end
  end

  defp dispatch_action("delete", goal, _input) do
    case OneAgent.Agents.delete_goal(goal) do
      {:ok, _} ->
        {:ok, %{
          "action" => "deleted",
          "success" => true,
          "goal_id" => goal.id,
          "note" => "Goal and all associated schedules deleted. Respond with a text message — do NOT call goal tools again."
        }}

      {:error, reason} ->
        {:error, "Failed to delete goal: #{inspect(reason)}"}
    end
  end

  # ── Formatting ────────────────────────────────────────────

  defp format_goal(%{steps: steps} = goal) when is_list(steps) do
    %{
      "id" => goal.id,
      "title" => goal.title,
      "description" => goal.description,
      "status" => goal.status,
      "priority" => goal.priority,
      "due_date" => goal.due_date && DateTime.to_iso8601(goal.due_date),
      "review_schedule_id" => goal.review_schedule_id,
      "steps" => Enum.map(steps, &format_step/1)
    }
  end

  defp format_goal(goal) do
    %{
      "id" => goal.id,
      "title" => goal.title,
      "description" => goal.description,
      "status" => goal.status,
      "priority" => goal.priority,
      "due_date" => goal.due_date && DateTime.to_iso8601(goal.due_date),
      "review_schedule_id" => goal.review_schedule_id
    }
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

  defp maybe_put_due_date(attrs, nil), do: attrs
  defp maybe_put_due_date(attrs, due_date_str) do
    case DateTime.from_iso8601(due_date_str) do
      {:ok, dt, _} -> Map.put(attrs, :due_date, dt)
      _ -> attrs
    end
  end
end
