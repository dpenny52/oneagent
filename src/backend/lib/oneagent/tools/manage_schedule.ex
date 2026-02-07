defmodule OneAgent.Tools.ManageSchedule do
  @moduledoc """
  Creates, updates, and deletes the agent's cron schedules.
  No permission bucket required — schedules are internal to the agent.
  """

  @behaviour OneAgent.Tools.Tool

  @impl true
  def id, do: "manage_schedule"

  @impl true
  def name, do: "Manage Schedule"

  @impl true
  def description do
    "Create, update, or delete your cron schedules. " <>
      "Use action 'create' with a cron expression, 'update' with a schedule_id and fields to change, " <>
      "or 'delete' with a schedule_id to remove a schedule."
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
          "enum" => ["create", "update", "delete"],
          "description" => "The action to perform: create, update, or delete a schedule."
        },
        "schedule_id" => %{
          "type" => "string",
          "description" => "The schedule ID (required for update and delete)."
        },
        "cron" => %{
          "type" => "string",
          "description" => "A cron expression (e.g. '*/5 * * * *'). Required for create, optional for update."
        },
        "message" => %{
          "type" => "string",
          "description" => "The message to send when the schedule fires. Optional."
        },
        "enabled" => %{
          "type" => "boolean",
          "description" => "Whether the schedule is enabled. Defaults to true on create."
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
    cron = input["cron"]
    message = input["message"]

    # Dedup: if a schedule with the same cron + message already exists, return it
    case find_duplicate(agent, cron, message) do
      %{} = existing ->
        {:ok, format_schedule(existing, "already_exists")}

      nil ->
        attrs =
          %{}
          |> maybe_put("cron", cron)
          |> maybe_put("message", message)
          |> maybe_put("enabled", input["enabled"])

        case OneAgent.Agents.create_schedule(agent, attrs) do
          {:ok, schedule} ->
            {:ok, format_schedule(schedule, "created")}

          {:error, changeset} ->
            {:error, format_errors(changeset)}
        end
    end
  end

  def execute(%{"action" => "update"} = input, context) do
    agent = context[:agent]

    case input["schedule_id"] do
      nil ->
        {:error, "schedule_id is required for update"}

      schedule_id ->
        case OneAgent.Agents.get_schedule(agent, schedule_id) do
          {:ok, schedule} ->
            attrs =
              %{}
              |> maybe_put("cron", input["cron"])
              |> maybe_put("message", input["message"])
              |> maybe_put("enabled", input["enabled"])

            case OneAgent.Agents.update_schedule(schedule, attrs) do
              {:ok, updated} ->
                {:ok, format_schedule(updated, "updated")}

              {:error, changeset} ->
                {:error, format_errors(changeset)}
            end

          {:error, :not_found} ->
            {:error, "Schedule not found: #{schedule_id}"}
        end
    end
  end

  def execute(%{"action" => "delete"} = input, context) do
    agent = context[:agent]

    case input["schedule_id"] do
      nil ->
        {:error, "schedule_id is required for delete"}

      schedule_id ->
        case OneAgent.Agents.get_schedule(agent, schedule_id) do
          {:ok, schedule} ->
            case OneAgent.Agents.delete_schedule(schedule) do
              {:ok, _} ->
                {:ok, %{"deleted" => true, "schedule_id" => schedule_id}}

              {:error, changeset} ->
                {:error, format_errors(changeset)}
            end

          {:error, :not_found} ->
            {:error, "Schedule not found: #{schedule_id}"}
        end
    end
  end

  def execute(%{"action" => action}, _context) do
    {:error, "Unknown action: #{action}. Use 'create', 'update', or 'delete'."}
  end

  def execute(_input, _context) do
    {:error, "Missing required parameter: action"}
  end

  defp format_schedule(schedule, action) do
    note = case action do
      "already_exists" ->
        "A schedule with this cron and message already exists. Tell the user it's already set up — do NOT call this tool again."
      _ ->
        "Schedule #{action} successfully. Tell the user what you did — do NOT call this tool again."
    end

    %{
      "action" => action,
      "success" => true,
      "schedule" => %{
        "id" => schedule.id,
        "cron" => schedule.cron,
        "message" => schedule.message,
        "enabled" => schedule.enabled,
        "last_run_at" => schedule.last_run_at && DateTime.to_iso8601(schedule.last_run_at)
      },
      "note" => note
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)
    |> Enum.join("; ")
  end

  defp find_duplicate(agent, cron, message) do
    OneAgent.Agents.list_schedules(agent)
    |> Enum.find(fn s -> s.cron == cron and s.message == message end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
