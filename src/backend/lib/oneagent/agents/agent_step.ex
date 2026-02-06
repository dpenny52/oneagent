defmodule OneAgent.Agents.AgentStep do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agent_steps" do
    field :step_number, :integer
    field :step_type, :string
    field :input, :map, default: %{}
    field :output, :map, default: %{}
    field :tool_id, :string
    field :bucket, :string
    field :tokens_used, :integer, default: 0
    field :duration_ms, :integer
    field :status, :string, default: "completed"

    belongs_to :run, OneAgent.Agents.AgentRun

    timestamps(type: :utc_datetime)
  end

  @valid_types ~w(llm_call tool_execution error)
  @valid_statuses ~w(completed failed)

  def changeset(step, attrs) do
    step
    |> cast(attrs, [:step_number, :step_type, :input, :output, :tool_id, :bucket, :tokens_used, :duration_ms, :status])
    |> validate_required([:step_number, :step_type])
    |> validate_inclusion(:step_type, @valid_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:run_id)
  end
end
