defmodule OneAgent.Runtime.AgentProcess do
  @moduledoc """
  GenServer for a running agent. Implements the agentic loop:
  receive trigger → build messages → LLM call → tool execution → log → repeat.
  """

  use GenServer, restart: :temporary
  require Logger

  alias OneAgent.{Agents, Credentials, LLM, Tools}

  defstruct [:agent, :llm_config, :api_key]

  # ── Client API ───────────────────────────────────────────────

  def start_link(agent) do
    GenServer.start_link(__MODULE__, agent,
      name: {:via, Registry, {OneAgent.Runtime.AgentRegistry, agent.id}}
    )
  end

  def invoke(agent_id, message, trigger \\ "manual") do
    case Registry.lookup(OneAgent.Runtime.AgentRegistry, agent_id) do
      [{pid, _}] -> GenServer.call(pid, {:invoke, message, trigger}, 300_000)
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
  def handle_call({:invoke, message, trigger}, _from, state) do
    result = run_agentic_loop(state, message, trigger)
    {:reply, result, state}
  end

  # ── Agentic Loop ─────────────────────────────────────────────

  defp run_agentic_loop(state, message, trigger) do
    agent = state.agent

    # Check daily run limit
    if Agents.count_runs_today(agent) >= agent.max_runs_per_day do
      {:error, "Daily run limit exceeded (#{agent.max_runs_per_day})"}
    else
      do_run(state, message, trigger)
    end
  end

  defp do_run(state, message, trigger) do
    agent = state.agent

    # Create run record
    {:ok, run} = Agents.create_run(agent, %{trigger: trigger})
    {:ok, run} = Agents.start_run(run)

    # Load conversation history and append current user message
    history = Agents.list_recent_messages(agent)
    history_messages = Enum.map(history, fn msg ->
      %{"role" => msg.role, "content" => msg.content}
    end)
    messages = history_messages ++ [%{"role" => "user", "content" => message}]

    # Get tool definitions filtered by agent's buckets
    tool_defs = Tools.tool_definitions_for_agent(agent)

    # Get relevant memories for context
    memories = Agents.list_memories(agent)
    system = build_system_prompt(agent, memories)

    # Run the loop
    case agentic_loop(state, run, messages, tool_defs, system, 0) do
      {:ok, final_text, run} ->
        # Persist user message and assistant response to chat history
        case Agents.create_message(agent, %{role: "user", content: message, run_id: run.id}) do
          {:ok, _} -> :ok
          {:error, cs} -> Logger.warning("Failed to save user message: #{inspect(cs.errors)}")
        end
        case Agents.create_message(agent, %{role: "assistant", content: final_text, run_id: run.id}) do
          {:ok, _} -> :ok
          {:error, cs} -> Logger.warning("Failed to save assistant message: #{inspect(cs.errors)}")
        end
        {:ok, %{run_id: run.id, response: final_text}}

      {:error, reason, run} ->
        # Persist user message even on error so context isn't lost
        Agents.create_message(agent, %{role: "user", content: message, run_id: run.id})
        Agents.fail_run(run, reason)
        {:error, reason}
    end
  end

  defp agentic_loop(state, run, messages, tool_defs, system, step_count) do
    agent = state.agent

    if step_count >= agent.max_steps_per_run do
      {:ok, run} = Agents.complete_run(run, %{total_steps: step_count})
      {:ok, "[Max steps reached (#{agent.max_steps_per_run})]", run}
    else
      start_time = System.monotonic_time(:millisecond)

      # Call LLM
      llm_result = LLM.chat(
        agent.model_provider,
        state.api_key,
        agent.model_id,
        messages,
        system: system,
        tools: tool_defs,
        max_tokens: Map.get(agent.model_config, "max_tokens", 4096)
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

            # LLM sometimes returns empty content after tool use — provide a fallback
            final_text = if final_text == "" do
              Logger.warning("LLM returned empty content for agent #{agent.id}, stop_reason=#{response.stop_reason}")
              "[Agent produced no response]"
            else
              final_text
            end

            {:ok, run} = Agents.complete_run(run, %{
              total_steps: step_count + 1,
              total_tokens_used: tokens
            })

            {:ok, final_text, run}
          else
            # Execute tools and continue loop
            {tool_results, new_step_count} =
              execute_tool_calls(state, run, tool_uses, step_count + 1)

            # Build updated messages with assistant response + tool results
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

            agentic_loop(state, run, updated_messages, tool_defs, system, new_step_count)
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

  defp execute_tool_calls(state, run, tool_uses, step_count) do
    agent = state.agent

    context = %{
      agent: agent,
      run: run,
      user_email: nil # Could be enriched with user data
    }

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

  defp build_system_prompt(agent, memories) do
    memory_section = case memories do
      [] -> ""
      mems ->
        items = Enum.map(mems, fn m ->
          "- #{m.key} (#{m.memory_type}): #{Jason.encode!(m.value)}"
        end)
        "\n\n## Your Memories\n#{Enum.join(items, "\n")}"
    end

    context_section = """

    ## How Your Memory Works
    - Your conversation history (the last #{agent.max_history_messages} messages) is included in this conversation. \
    For recent questions like "what did I just ask?", refer to the messages above — do NOT use recall_memory for that.
    - Use store_memory to save important facts, preferences, or patterns that should persist beyond the conversation window.
    - Use recall_memory only when you need to retrieve something you previously stored with store_memory.
    - Always respond with a text message. Never end your turn silently after using a tool.
    """

    agent.system_prompt <> context_section <> memory_section
  end

  defp resolve_api_key(agent) do
    case agent.llm_config do
      %Credentials.LlmConfig{} = config ->
        {:ok, Credentials.decrypt_api_key(config)}

      nil ->
        {:error, "No LLM configuration assigned to this agent"}
    end
  end
end
