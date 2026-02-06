defmodule OneAgent.Agents.AgentRun do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agent_runs" do
    field :status, :string, default: "pending"
    field :trigger, :string
    field :trigger_payload, :map, default: %{}
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :total_tokens_used, :integer, default: 0
    field :total_steps, :integer, default: 0
    field :error_message, :string

    belongs_to :agent, OneAgent.Agents.Agent
    has_many :steps, OneAgent.Agents.AgentStep, foreign_key: :run_id

    timestamps(type: :utc_datetime)
  end

  @valid_statuses ~w(pending running completed failed cancelled)
  @valid_triggers ~w(manual scheduled webhook continuous)

  def changeset(run, attrs) do
    run
    |> cast(attrs, [:trigger, :trigger_payload, :status])
    |> validate_required([:trigger])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:trigger, @valid_triggers)
    |> foreign_key_constraint(:agent_id)
  end

  def start_changeset(run) do
    change(run, status: "running", started_at: DateTime.utc_now(:second))
  end

  def complete_changeset(run, attrs \\ %{}) do
    run
    |> cast(attrs, [:total_tokens_used, :total_steps])
    |> put_change(:status, "completed")
    |> put_change(:completed_at, DateTime.utc_now(:second))
  end

  def fail_changeset(run, error_message) do
    run
    |> change(status: "failed", error_message: error_message, completed_at: DateTime.utc_now(:second))
  end
end
