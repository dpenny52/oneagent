defmodule OneAgent.Tools.ListSchedules do
  @moduledoc """
  Lists the agent's cron schedules.
  No permission bucket required — schedules are internal to the agent.
  """

  @behaviour OneAgent.Tools.Tool

  @impl true
  def id, do: "list_schedules"

  @impl true
  def name, do: "List Schedules"

  @impl true
  def description do
    "List your cron schedules. Returns all schedules by default, or only enabled ones if enabled_only is true."
  end

  @impl true
  def bucket, do: nil

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "enabled_only" => %{
          "type" => "boolean",
          "description" => "If true, only return enabled schedules. Defaults to false."
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
    schedules = OneAgent.Agents.list_schedules(agent)

    schedules =
      if input["enabled_only"] do
        Enum.filter(schedules, & &1.enabled)
      else
        schedules
      end

    items =
      Enum.map(schedules, fn s ->
        %{
          "id" => s.id,
          "cron" => s.cron,
          "message" => s.message,
          "enabled" => s.enabled,
          "last_run_at" => s.last_run_at && DateTime.to_iso8601(s.last_run_at)
        }
      end)

    {:ok, %{"schedules" => items, "count" => length(items)}}
  end
end
