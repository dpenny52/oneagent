defmodule OneAgent.Runtime.AgentProcess do
  @moduledoc """
  GenServer for a running agent. Implements the agentic loop:
  receive trigger → build messages → LLM call → tool execution → log → repeat.
  """

  use GenServer, restart: :temporary
  require Logger

  alias OneAgent.{Agents, Credentials, LLM, Tools}

  # Maximum wall-clock time for a single agent run (default: 2 minutes)
  @default_max_run_duration_ms 120_000

  defp max_run_duration_ms do
    Application.get_env(:oneagent, :max_run_duration_ms, @default_max_run_duration_ms)
  end

  defstruct [:agent, :llm_config, :api_key]

  # ── Client API ───────────────────────────────────────────────

  def start_link(agent) do
    GenServer.start_link(__MODULE__, agent,
      name: {:via, Registry, {OneAgent.Runtime.AgentRegistry, agent.id}}
    )
  end

  def invoke(agent_id, message, trigger \\ "manual", opts \\ %{}) do
    case Registry.lookup(OneAgent.Runtime.AgentRegistry, agent_id) do
      [{pid, _}] -> GenServer.call(pid, {:invoke, message, trigger, opts}, max_run_duration_ms() + 30_000)
      [] -> {:error, :not_running}
    end
  end

  # ── Server Callbacks ─────────────────────────────────────────

  @impl true
  def init(agent) do
    # Load the LLM config
    agent = OneAgent.Repo.preload(agent, :llm_config)

    case resolve_api_key(agent) do
      {:ok, api_key} ->
        {:ok, %__MODULE__{agent: agent, llm_config: agent.llm_config, api_key: api_key}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:invoke, message, trigger, opts}, _from, state) do
    result = run_agentic_loop(state, message, trigger, opts)
    {:reply, result, state}
  end

  # ── Agentic Loop ─────────────────────────────────────────────

  defp run_agentic_loop(state, message, trigger, opts) do
    # Reload agent from DB to pick up any setting changes (e.g. max_runs_per_day)
    agent = OneAgent.Repo.get(Agents.Agent, state.agent.id) || state.agent

    # Check daily run limit
    if Agents.count_runs_today(agent) >= agent.max_runs_per_day do
      {:error, "Daily run limit exceeded (#{agent.max_runs_per_day})"}
    else
      do_run(%{state | agent: agent}, message, trigger, opts)
    end
  end

  defp do_run(state, message, trigger, opts) do
    agent = state.agent
    source = derive_source(trigger, opts)
    deadline = System.monotonic_time(:millisecond) + max_run_duration_ms()

    # Create run record
    {:ok, run} = Agents.create_run(agent, %{trigger: trigger})
    {:ok, run} = Agents.start_run(run)

    # Load conversation history and append current user message
    # Prefix user messages with their channel source so the LLM knows the origin
    history = Agents.list_recent_messages(agent)
    history_messages = Enum.map(history, fn msg ->
      content = if msg.role == "user", do: source_label(msg.source) <> msg.content, else: msg.content
      %{"role" => msg.role, "content" => content}
    end)
    messages = history_messages ++ [%{"role" => "user", "content" => source_label(source) <> message}]

    # Get tool definitions filtered by agent's buckets (and trigger source)
    tool_defs = Tools.tool_definitions_for_agent(agent, trigger, opts)

    # Get relevant memories, schedules, and goals for context
    memories = Agents.list_memories(agent)
    schedules = Agents.list_schedules(agent)
    goals = Agents.list_goals(agent, status: "active")
    system = build_system_prompt(agent, memories, schedules, goals)

    # Run the loop
    case agentic_loop(state, run, messages, tool_defs, system, 0, [], deadline, trigger, opts) do
      {:ok, final_text, run} ->
        # Persist user message and assistant response to chat history
        case Agents.create_message(agent, %{role: "user", content: message, run_id: run.id, source: source}) do
          {:ok, _} -> :ok
          {:error, cs} -> Logger.warning("Failed to save user message: #{inspect(cs.errors)}")
        end
        case Agents.create_message(agent, %{role: "assistant", content: final_text, run_id: run.id, source: source}) do
          {:ok, _} -> :ok
          {:error, cs} -> Logger.warning("Failed to save assistant message: #{inspect(cs.errors)}")
        end
        {:ok, %{run_id: run.id, response: final_text}}

      {:error, reason, run} ->
        # Persist user message even on error so context isn't lost
        Agents.create_message(agent, %{role: "user", content: message, run_id: run.id, source: source})
        Agents.fail_run(run, reason)
        {:error, reason}
    end
  end

  defp agentic_loop(state, run, messages, tool_defs, system, step_count, prev_tools, deadline, trigger, opts) do
    agent = state.agent

    cond do
      step_count >= agent.max_steps_per_run ->
        {:ok, run} = Agents.complete_run(run, %{total_steps: step_count})
        {:ok, "[Max steps reached (#{agent.max_steps_per_run})]", run}

      System.monotonic_time(:millisecond) >= deadline ->
        {:ok, run} = Agents.complete_run(run, %{total_steps: step_count})
        {:ok, "[Run timed out after #{div(max_run_duration_ms(), 1000)} seconds]", run}

      true ->
        # Throttle between iterations to avoid LLM API rate limits.
        # Skip the first iteration (step_count == 0) so initial response is instant.
        if step_count > 0, do: Process.sleep(1_500)

        start_time = System.monotonic_time(:millisecond)

        # Budget the LLM call so it can't exceed the run deadline.
        # Reserve 5 s for GenServer overhead; allow 1 retry when > 60 s remain.
        remaining_ms = deadline - start_time
        timeout = remaining_ms |> Kernel.-(5_000) |> min(120_000) |> max(5_000)
        retries = if remaining_ms > 60_000, do: 1, else: 0

        # Call LLM
        llm_result = LLM.chat(
          agent.model_provider,
          state.api_key,
          agent.model_id,
          messages,
          system: system,
          tools: tool_defs,
          max_tokens: Map.get(agent.model_config, "max_tokens", 4096),
          receive_timeout: timeout,
          max_retries: retries
        )

        duration_ms = System.monotonic_time(:millisecond) - start_time

        case llm_result do
          {:ok, response} ->
            # Log LLM call step
            tokens = response.usage.input_tokens + response.usage.output_tokens
            {:ok, _step} = Agents.create_step(run, %{
              step_number: step_count + 1,
              step_type: "llm_call",
              input: %{"message_count" => length(messages)},
              output: %{"stop_reason" => response.stop_reason, "content_blocks" => length(response.content)},
              tokens_used: tokens,
              duration_ms: duration_ms
            })

            # Check for tool use
            tool_uses = Enum.filter(response.content, &(&1.type == :tool_use))

            if tool_uses == [] do
              # No tool use — extract text and complete
              final_text = response.content
                |> Enum.filter(&(&1.type == :text))
                |> Enum.map(& &1.text)
                |> Enum.join("\n")

              # LLM sometimes returns empty content after tool use — retry once WITHOUT tools,
              # including recent tool results so the LLM has context to form a response
              if final_text == "" and step_count > 0 and step_count < agent.max_steps_per_run - 1 do
                Logger.warning("LLM returned empty content for agent #{agent.id}, retrying without tools")

                tool_summary = extract_recent_tool_results(messages)

                nudge_text = case tool_summary do
                  "" -> "[System: Please respond with a text message to the user.]"
                  summary -> "[System: Your tool call returned: #{summary}. Please tell the user about these results.]"
                end

                nudge = %{"role" => "user", "content" => [
                  %{"type" => "text", "text" => nudge_text}
                ]}

                retry_messages = messages ++ [
                  %{"role" => "assistant", "content" => []},
                  nudge
                ]

                # Pass empty tools list to force text-only response
                agentic_loop(state, run, retry_messages, [], system, step_count + 1, prev_tools, deadline, trigger, opts)
              else
                final_text = if final_text == "", do: "[Agent produced no response]", else: final_text

                {:ok, run} = Agents.complete_run(run, %{
                  total_steps: step_count + 1,
                  total_tokens_used: tokens
                })

                {:ok, final_text, run}
              end
            else
              current_tools = tool_uses |> Enum.map(& &1.name) |> Enum.sort()

              # Detect repeated tool calls BEFORE executing — if LLM is calling the
              # same tools as last round, skip execution and nudge with previous results
              if current_tools == prev_tools and prev_tools != [] do
                Logger.warning("Agent #{agent.id} repeated tool calls #{inspect(current_tools)}, skipping and forcing text response")

                prev_tool_summary = extract_recent_tool_results(messages)

                nudge = %{"role" => "user", "content" => [
                  %{"type" => "text", "text" => "[System: You already completed this action successfully. The results were: #{prev_tool_summary}. Do NOT call any more tools. Respond to the user confirming what you did.]"}
                ]}

                nudge_messages = messages ++ [
                  %{"role" => "assistant", "content" => []},
                  nudge
                ]

                agentic_loop(state, run, nudge_messages, [], system, step_count + 1, current_tools, deadline, trigger, opts)
              else
                # Execute tools and continue loop
                {tool_results, new_step_count} =
                  execute_tool_calls(state, run, tool_uses, step_count + 1, trigger, opts)

                # Loop back to LLM for a text response
                assistant_content = Enum.map(response.content, fn
                  %{type: :text, text: text} -> %{"type" => "text", "text" => text}
                  %{type: :tool_use, id: id, name: name, input: input} ->
                    %{"type" => "tool_use", "id" => id, "name" => name, "input" => input}
                end)

                tool_result_msgs = Enum.map(tool_results, fn {tool_use_id, result} ->
                  %{
                    "type" => "tool_result",
                    "tool_use_id" => tool_use_id,
                    "content" => Jason.encode!(result)
                  }
                end)

                updated_messages = messages ++ [
                  %{"role" => "assistant", "content" => assistant_content},
                  %{"role" => "user", "content" => tool_result_msgs}
                ]

                agentic_loop(state, run, updated_messages, tool_defs, system, new_step_count, current_tools, deadline, trigger, opts)
              end
            end

          {:error, reason} ->
            Agents.create_step(run, %{
              step_number: step_count + 1,
              step_type: "error",
              output: %{"error" => reason},
              duration_ms: duration_ms,
              status: "failed"
            })

            {:error, reason, run}
        end
    end
  end

  defp execute_tool_calls(state, run, tool_uses, step_count, trigger, opts) do
    agent = state.agent

    context = Map.merge(%{
      agent: agent,
      run: run,
      trigger: trigger,
      user_email: nil
    }, opts)

    {results, final_step} =
      Enum.reduce(tool_uses, {[], step_count}, fn tool_use, {acc, current_step} ->
        start_time = System.monotonic_time(:millisecond)

        result = Tools.execute_tool(tool_use.name, tool_use.input, context)
        duration_ms = System.monotonic_time(:millisecond) - start_time

        {output, status} = case result do
          {:ok, output} -> {output, "completed"}
          {:error, reason} -> {%{"error" => reason}, "failed"}
        end

        # Determine which bucket was used
        bucket = case Tools.get_tool(tool_use.name) do
          nil -> nil
          tool_mod ->
            case tool_mod.bucket() do
              nil ->
                if function_exported?(tool_mod, :bucket_for_input, 1),
                  do: to_string(tool_mod.bucket_for_input(tool_use.input)),
                  else: nil
              b -> to_string(b)
            end
        end

        # Log tool execution step (credential values redacted — never in output)
        Agents.create_step(run, %{
          step_number: current_step + 1,
          step_type: "tool_execution",
          input: %{"tool" => tool_use.name, "args" => tool_use.input},
          output: output,
          tool_id: tool_use.name,
          bucket: bucket,
          duration_ms: duration_ms,
          status: status
        })

        {[{tool_use.id, output} | acc], current_step + 1}
      end)

    {Enum.reverse(results), final_step}
  end

  defp build_system_prompt(agent, memories, schedules, goals) do
    memory_section = case memories do
      [] -> ""
      mems ->
        items = Enum.map(mems, fn m ->
          "- #{m.key} (#{m.memory_type}): #{Jason.encode!(m.value)}"
        end)
        "\n\n## Your Memories\n#{Enum.join(items, "\n")}"
    end

    schedule_section = case schedules do
      [] -> ""
      scheds ->
        items = Enum.map(scheds, fn s ->
          status = if s.enabled, do: "enabled", else: "disabled"
          last_run = if s.last_run_at, do: " (last ran: #{DateTime.to_iso8601(s.last_run_at)})", else: ""
          message = if s.message, do: " — \"#{s.message}\"", else: ""
          "- [#{s.id}] #{s.cron} (#{status})#{message}#{last_run}"
        end)
        "\n\n## Your Schedules\n#{Enum.join(items, "\n")}"
    end

    # Cap at 10 active goals to prevent token bloat
    goals_section = case Enum.take(goals, 10) do
      [] -> ""
      active_goals ->
        items = Enum.map(active_goals, fn goal ->
          steps = goal.steps || []
          completed = Enum.count(steps, &(&1.status == "completed"))

          priority_label = cond do
            goal.priority >= 3 -> "HIGH"
            goal.priority >= 1 -> "MED"
            true -> "LOW"
          end

          review_info = case goal.review_schedule do
            %{cron: cron, id: id} -> "\n  Review: #{cron} (schedule: #{id})"
            _ -> ""
          end

          due_info = if goal.due_date, do: "\n  Due: #{DateTime.to_iso8601(goal.due_date)}", else: ""

          step_lines = Enum.map(steps, fn s ->
            status_icon = case s.status do
              "completed" -> "DONE"
              "in_progress" -> "IN PROGRESS"
              "skipped" -> "SKIPPED"
              _ -> " "
            end

            notes = if s.result_notes, do: " — \"#{s.result_notes}\"", else: ""
            sched_info = if s.schedule_id, do: " (schedule: #{s.schedule_id})", else: ""

            "  #{s.position}. [#{status_icon}] #{s.title}#{notes}#{sched_info}"
          end)

          """
          ### [#{priority_label}] #{goal.title} (goal_id: #{goal.id})#{review_info}#{due_info}
            Progress: #{completed}/#{length(steps)} steps completed
          #{Enum.join(step_lines, "\n")}
          """
        end)

        "\n\n## Your Goals\n#{Enum.join(items, "\n")}"
    end

    context_section = """

    ## Message Channels
    - Each user message is prefixed with its source channel (e.g., [via Telegram], [via WhatsApp], [via Web Chat]).
    - Be aware of which channel you're responding on. Keep messages concise on chat apps (Telegram, WhatsApp).
    - When a user switches channels, don't be confused — it's the same person reaching you from a different app.

    ## How Your Memory Works
    - Your conversation history (the last #{agent.max_history_messages} messages) is included in this conversation. \
    For recent questions like "what did I just ask?", refer to the messages above — do NOT use recall_memory for that.
    - Use store_memory to save important facts, preferences, or patterns that should persist beyond the conversation window.
    - Use recall_memory only when you need to retrieve something you previously stored with store_memory. \
    You can also use recall_memory with the "search" parameter to find memories by keyword.
    - Always respond with a text message. Never end your turn silently after using a tool.

    ## Schedule Management
    - Use list_schedules to see your current cron schedules (or check the "Your Schedules" section above).
    - Use manage_schedule with action "create" to add a new schedule, "update" to modify one, or "delete" to remove one.
    - Schedule IDs shown in brackets (e.g. [abc-123]) can be used as the schedule_id parameter for update/delete.
    - Cron format: "minute hour day-of-month month day-of-week" (e.g. "*/5 * * * *" = every 5 minutes, "0 9 * * 1-5" = weekdays at 9am).
    - IMPORTANT: After a manage_schedule call succeeds, immediately respond with a text message confirming the action. \
    Never call manage_schedule again after a successful result — one call per action is all you need.

    ## Goal Management
    - When a user gives you a vague objective (like "help me find a job"), create a goal with concrete steps using manage_goal. \
    Include cron expressions on steps that need periodic execution.
    - Each goal gets an automatic hourly review schedule. During reviews: check step progress, update statuses, \
    create/remove step schedules as needed, and take the next action.
    - If hourly review is too frequent for a goal, use manage_schedule to change the review schedule's cron (e.g., to daily "0 9 * * *").
    - Use manage_goal_step to add, update, complete, skip, or remove individual steps. Use list_goals to see current progress.
    - IMPORTANT: After creating or modifying a goal, immediately respond with a text message describing your plan. \
    Do NOT call goal tools again after a successful result.

    ## Scheduled Execution Context
    - When you run on a schedule, your messages are NOT stored in conversation history.
    - If you discover important information during a scheduled run, use store_memory to save it.
    - Your stored memories persist across all runs and are always available above.
    """

    agent.system_prompt <> context_section <> memory_section <> schedule_section <> goals_section
  end

  # Extracts the most recent tool_result content from the message history
  defp extract_recent_tool_results(messages) do
    messages
    |> Enum.reverse()
    |> Enum.find_value(fn
      %{"role" => "user", "content" => content} when is_list(content) ->
        results = Enum.filter(content, &(is_map(&1) and &1["type"] == "tool_result"))
        if results != [], do: Enum.map_join(results, "; ", & &1["content"])

      _ -> nil
    end)
    |> Kernel.||("")
  end

  defp trigger_to_source("manual"), do: "chat"
  defp trigger_to_source("webhook"), do: "webhook"
  defp trigger_to_source("scheduled"), do: "scheduled"
  defp trigger_to_source(_), do: "chat"

  # Derive a channel-specific source when available, otherwise fall back to trigger
  defp derive_source(trigger, %{channel: channel}) when channel in ~w(telegram whatsapp), do: channel
  defp derive_source(trigger, _opts), do: trigger_to_source(trigger)

  # Labels prepended to user messages so the LLM knows which channel they came from
  defp source_label("telegram"), do: "[via Telegram] "
  defp source_label("whatsapp"), do: "[via WhatsApp] "
  defp source_label("webhook"), do: "[via Webhook] "
  defp source_label("scheduled"), do: "[via Scheduled Run] "
  defp source_label("chat"), do: "[via Web Chat] "
  defp source_label(_), do: ""

  defp resolve_api_key(agent) do
    case agent.llm_config do
      %Credentials.LlmConfig{} = config ->
        {:ok, Credentials.decrypt_api_key(config)}

      nil ->
        {:error, "No LLM configuration assigned to this agent"}
    end
  end
end
