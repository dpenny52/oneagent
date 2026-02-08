defmodule OneAgent.Tools.StoreMemory do
  @moduledoc """
  Stores a fact, preference, or pattern in the agent's persistent memory.
  No permission bucket required — memory is internal to the agent.
  """

  @behaviour OneAgent.Tools.Tool

  @max_memories_per_agent 500

  @impl true
  def id, do: "store_memory"

  @impl true
  def name, do: "Store Memory"

  @impl true
  def description do
    "Store a piece of information in your persistent memory. Use this to remember facts, preferences, or patterns you've learned."
  end

  @impl true
  def bucket, do: nil

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "key" => %{
          "type" => "string",
          "description" => "A unique key for this memory (e.g. 'user_preference_timezone')"
        },
        "value" => %{
          "type" => "object",
          "description" => "The value to store (any JSON object)"
        },
        "memory_type" => %{
          "type" => "string",
          "enum" => ["fact", "preference", "conversation_summary", "learned_pattern"],
          "description" => "The type of memory"
        }
      },
      "required" => ["key", "value", "memory_type"]
    }
  end

  @impl true
  def required_credential_type, do: nil

  @impl true
  def execute(input, context) do
    agent = context[:agent]
    run = context[:run]
    key = input["key"]

    # Check memory count limit only for new keys (upserts on existing keys are always allowed)
    existing = OneAgent.Agents.get_memory(agent, key)

    if is_nil(existing) and OneAgent.Agents.count_memories(agent) >= @max_memories_per_agent do
      {:error, "Memory limit reached (maximum #{@max_memories_per_agent} per agent). Delete unused memories before storing new ones."}
    else
      attrs = %{
        key: key,
        value: input["value"],
        memory_type: input["memory_type"],
        source_run_id: run && run.id
      }

      case OneAgent.Agents.upsert_memory(agent, attrs) do
        {:ok, memory} ->
          {:ok, %{"key" => memory.key, "stored" => true}}

        {:error, changeset} ->
          {:error, "Failed to store memory: #{OneAgent.ChangesetErrors.format(changeset)}"}
      end
    end
  end
end
