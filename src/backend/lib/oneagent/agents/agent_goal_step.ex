defmodule OneAgent.Agents.AgentGoalStep do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agent_goal_steps" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "pending"
    field :position, :integer
    field :completed_at, :utc_datetime
    field :result_notes, :string

    belongs_to :goal, OneAgent.Agents.AgentGoal
    belongs_to :schedule, OneAgent.Agents.AgentSchedule

    timestamps(type: :utc_datetime)
  end

  @valid_statuses ~w(pending in_progress completed skipped)

  @required_fields [:title, :position]
  @optional_fields [:description, :status, :completed_at, :result_notes, :schedule_id]

  def changeset(step, attrs) do
    step
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:title, max: 500)
    |> validate_length(:description, max: 5000)
    |> validate_length(:result_notes, max: 5000)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:goal_id)
    |> foreign_key_constraint(:schedule_id)
  end
end
