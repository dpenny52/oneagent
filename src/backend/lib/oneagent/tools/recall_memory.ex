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
    "Recall information from your persistent memory. Use a specific key to retrieve a memory, use search to find memories by keyword, or leave both empty to list all memories."
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
          "description" => "The exact key of the memory to recall. Takes priority over search."
        },
        "search" => %{
          "type" => "string",
          "description" => "Search query to find memories by keyword. Supports Google-style syntax: quoted phrases (\"exact match\"), OR (term1 OR term2), exclusion (-term). Searches across keys, values, and memory types."
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
    key = normalize_key(input["key"])
    search = normalize_key(input["search"])

    cond do
      # Priority 1: exact key lookup
      key != nil ->
        case OneAgent.Agents.get_memory(agent, key) do
          nil -> {:ok, %{"found" => false, "key" => key}}
          memory -> {:ok, %{"found" => true, "key" => key, "value" => memory.value, "type" => memory.memory_type}}
        end

      # Priority 2: full-text search
      search != nil ->
        results = OneAgent.Agents.search_memories(agent, search)
        items = Enum.map(results, fn %{memory: m, rank: rank} ->
          %{"key" => m.key, "type" => m.memory_type, "value" => m.value, "relevance" => Float.round(rank, 4)}
        end)
        {:ok, %{"memories" => items, "count" => length(items), "query" => search}}

      # Priority 3: list all
      true ->
        memories = OneAgent.Agents.list_memories(agent)
        items = Enum.map(memories, fn m ->
          %{"key" => m.key, "type" => m.memory_type, "value" => m.value}
        end)
        {:ok, %{"memories" => items, "count" => length(items)}}
    end
  end

  # Treat empty/whitespace-only strings as nil (list all memories)
  defp normalize_key(nil), do: nil
  defp normalize_key(key) when is_binary(key) do
    case String.trim(key) do
      "" -> nil
      trimmed -> trimmed
    end
  end
  defp normalize_key(_), do: nil
end
