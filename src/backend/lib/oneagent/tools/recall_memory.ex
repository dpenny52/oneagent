defmodule OneAgent.Tools.RecallMemory do
  @moduledoc """
  Retrieves information from the agent's persistent memory.
  No permission bucket required — memory is internal to the agent.
  """

  @behaviour OneAgent.Tools.Tool

  @impl true
  def id, do: "recall_memory"

  @impl true
  def name, do: "Recall Memory"

  @impl true
  def description do
    "Recall information from your persistent memory. Use a specific key to retrieve a memory, or leave key empty to list all memories."
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
          "description" => "The key of the memory to recall. Omit to list all memories."
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

    case input["key"] do
      nil ->
        memories = OneAgent.Agents.list_memories(agent)
        items = Enum.map(memories, fn m ->
          %{"key" => m.key, "type" => m.memory_type, "value" => m.value}
        end)
        {:ok, %{"memories" => items, "count" => length(items)}}

      key ->
        case OneAgent.Agents.get_memory(agent, key) do
          nil -> {:ok, %{"found" => false, "key" => key}}
          memory -> {:ok, %{"found" => true, "key" => key, "value" => memory.value, "type" => memory.memory_type}}
        end
    end
  end
end
