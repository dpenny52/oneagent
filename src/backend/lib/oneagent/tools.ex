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
    OneAgent.Tools.ManageCalendar,
    OneAgent.Tools.SendWhatsApp,
    OneAgent.Tools.SendTelegram,
    OneAgent.Tools.WebSearch,
    OneAgent.Tools.StoreMemory,
    OneAgent.Tools.RecallMemory,
    OneAgent.Tools.ListSchedules,
    OneAgent.Tools.ManageSchedule,
    OneAgent.Tools.ManageGoal,
    OneAgent.Tools.ManageGoalStep,
    OneAgent.Tools.ListGoals,
    OneAgent.Tools.PolymarketMarkets,
    OneAgent.Tools.PolymarketTrade,
    OneAgent.Tools.PolymarketPortfolio,
    OneAgent.Tools.EvmBalance,
    OneAgent.Tools.EvmTransfer,
    OneAgent.Tools.EvmSwap,
    OneAgent.Tools.EvmRead
  ]

  # Actions restricted for webhook-triggered runs to mitigate prompt injection.
  # External messages (e.g., WhatsApp) should not be able to manipulate the
  # agent's internal configuration (schedules, goals, memories).
  @webhook_restricted_actions %{
    "manage_schedule" => MapSet.new(["delete", "update", "create"]),
    "manage_goal" => MapSet.new(["delete", "abandon", "complete", "pause", "create"]),
    "manage_goal_step" => MapSet.new(["remove", "skip", "complete", "add", "add_schedule", "remove_schedule"]),
    "manage_calendar" => MapSet.new(["create_event", "update_event", "delete_event"]),
    "send_whatsapp" => :all,
    "send_telegram" => :all,
    "store_memory" => :all,
    "polymarket_trade" => :all,
    "polymarket_portfolio" => :all,
    "evm_transfer" => :all,
    "evm_swap" => :all
  }

  @doc """
  Returns all registered tool modules.
  """
  def all_tools, do: @tools

  @doc """
  Returns tool definitions for the LLM, filtered to only tools
  in the agent's approved buckets. Memory tools always included.

  When `trigger` is `"webhook"` and the sender is not trusted,
  management tools (schedule, goal, memory) are excluded to
  prevent prompt injection via external messages. Trusted senders
  (channel owners) bypass these restrictions.
  """
  def tool_definitions_for_agent(agent, trigger \\ "manual", opts \\ %{}) do
    active_buckets =
      Agents.list_active_buckets(agent)
      |> Enum.map(& &1.bucket)
      |> MapSet.new()

    trusted = Map.get(opts, :trusted_sender, false)

    # Tools fully restricted for webhook triggers (all actions blocked)
    webhook_excluded_tools =
      if trigger == "webhook" and not trusted do
        @webhook_restricted_actions
        |> Enum.filter(fn {_id, restriction} -> restriction == :all end)
        |> Enum.map(fn {id, _} -> id end)
        |> MapSet.new()
      else
        MapSet.new()
      end

    @tools
    |> Enum.filter(fn tool_mod ->
      # Exclude tools fully restricted for webhook triggers
      not MapSet.member?(webhook_excluded_tools, tool_mod.id()) and
        case tool_mod.bucket() do
          nil ->
            # http_request has a dynamic bucket — only include if agent has web_access or data_write
            if tool_mod == HttpRequest do
              MapSet.member?(active_buckets, "web_access") or
                MapSet.member?(active_buckets, "data_write")
            else
              true
            end

          bucket ->
            MapSet.member?(active_buckets, to_string(bucket))
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
        # Check webhook restrictions before executing
        if webhook_restricted?(tool_id, input, context) do
          {:error, "This action is not available during webhook-triggered runs"}
        else
          required_bucket = resolve_bucket(tool_mod, input)

          cond do
            # No bucket required (memory/management tools)
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
  end

  defp webhook_restricted?(tool_id, input, context) do
    trigger = Map.get(context, :trigger)
    trusted = Map.get(context, :trusted_sender, false)

    trigger == "webhook" and not trusted and
      case Map.get(@webhook_restricted_actions, tool_id) do
        nil -> false
        :all -> true
        actions -> MapSet.member?(actions, input["action"])
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
