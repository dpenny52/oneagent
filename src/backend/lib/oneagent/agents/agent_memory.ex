defmodule OneAgent.Agents.AgentMemory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agent_memories" do
    field :key, :string
    field :value, :map
    field :memory_type, :string
    field :confidence, :float, default: 1.0
    field :expires_at, :utc_datetime

    belongs_to :agent, OneAgent.Agents.Agent
    belongs_to :source_run, OneAgent.Agents.AgentRun

    timestamps(type: :utc_datetime)
  end

  @valid_types ~w(fact preference conversation_summary learned_pattern)

  # Maximum serialized size of a memory value (10 KB).
  # Memories are injected into the system prompt on every LLM call,
  # so unbounded values would bloat token usage and cost.
  @max_value_bytes 10_000

  def changeset(memory, attrs) do
    memory
    |> cast(attrs, [:key, :value, :memory_type, :confidence, :expires_at, :source_run_id])
    |> validate_required([:key, :value, :memory_type])
    |> validate_inclusion(:memory_type, @valid_types)
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_length(:key, min: 1, max: 255)
    |> validate_value_size()
    |> foreign_key_constraint(:agent_id)
    |> unique_constraint([:agent_id, :key])
  end

  defp validate_value_size(changeset) do
    case get_change(changeset, :value) do
      nil ->
        changeset

      value ->
        encoded_size = value |> Jason.encode!() |> byte_size()

        if encoded_size > @max_value_bytes do
          add_error(changeset, :value, "is too large (%{size} bytes, maximum is %{max} bytes)",
            size: encoded_size,
            max: @max_value_bytes
          )
        else
          changeset
        end
    end
  end
end
