defmodule OneAgent.Tools do
  @moduledoc """
  Tool registry and executor. Resolves tools, checks bucket permissions,
  and executes with credential injection.
  """

  alias OneAgent.Agents
  alias OneAgent.Credentials
  alias OneAgent.Tools.HttpRequest

  @tools [
    OneAgent.Tools.HttpRequest,
    OneAgent.Tools.ReadWebpage,
    OneAgent.Tools.SendEmail,
    OneAgent.Tools.CheckEmail,
    OneAgent.Tools.WebSearch,
    OneAgent.Tools.StoreMemory,
    OneAgent.Tools.RecallMemory,
    OneAgent.Tools.ListSchedules,
    OneAgent.Tools.ManageSchedule,
    OneAgent.Tools.ManageGoal,
    OneAgent.Tools.ManageGoalStep,
    OneAgent.Tools.ListGoals
  ]

  @doc """
  Returns all registered tool modules.
  """
  def all_tools, do: @tools

  @doc """
  Returns tool definitions for the LLM, filtered to only tools
  in the agent's approved buckets. Memory tools always included.
  """
  def tool_definitions_for_agent(agent) do
    active_buckets =
      Agents.list_active_buckets(agent)
      |> Enum.map(& &1.bucket)
      |> MapSet.new()

    @tools
    |> Enum.filter(fn tool_mod ->
      case tool_mod.bucket() do
        nil -> true  # memory tools + http_request (dynamic bucket)
        bucket -> MapSet.member?(active_buckets, to_string(bucket))
      end
    end)
    |> Enum.map(&tool_to_definition/1)
  end

  @doc """
  Resolves a tool module by its ID string.
  """
  def get_tool(tool_id) do
    Enum.find(@tools, fn mod -> mod.id() == tool_id end)
  end

  @doc """
  Executes a tool call with bucket permission checking and credential injection.

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  def execute_tool(tool_id, input, %{agent: agent} = context) do
    case get_tool(tool_id) do
      nil ->
        {:error, "Unknown tool: #{tool_id}"}

      tool_mod ->
        required_bucket = resolve_bucket(tool_mod, input)

        cond do
          # No bucket required (memory tools)
          required_bucket == nil ->
            tool_mod.execute(input, context)

          # Check if agent has the required bucket
          not Agents.has_bucket?(agent, to_string(required_bucket)) ->
            {:error, "Permission denied: agent does not have the '#{required_bucket}' permission bucket"}

          true ->
            context = maybe_inject_credential(context, agent, to_string(required_bucket))
            tool_mod.execute(input, context)
        end
    end
  end

  defp resolve_bucket(HttpRequest, input), do: HttpRequest.bucket_for_input(input)
  defp resolve_bucket(tool_mod, _input), do: tool_mod.bucket()

  defp maybe_inject_credential(context, agent, bucket_name) do
    case Agents.get_bucket_with_credential(agent, bucket_name) do
      %{credential: %Credentials.Credential{} = cred} ->
        value = Credentials.decrypt_credential(cred)
        Map.put(context, :credential_value, value)

      _ ->
        context
    end
  end

  defp tool_to_definition(tool_mod) do
    %{
      "name" => tool_mod.id(),
      "description" => tool_mod.description(),
      "input_schema" => tool_mod.parameters_schema()
    }
  end
end
