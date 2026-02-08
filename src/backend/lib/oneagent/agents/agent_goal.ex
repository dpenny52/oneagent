defmodule OneAgent.Agents.AgentGoal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agent_goals" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "active"
    field :priority, :integer, default: 0
    field :completed_at, :utc_datetime
    field :due_date, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :agent, OneAgent.Agents.Agent
    belongs_to :source_run, OneAgent.Agents.AgentRun
    belongs_to :review_schedule, OneAgent.Agents.AgentSchedule

    has_many :steps, OneAgent.Agents.AgentGoalStep, foreign_key: :goal_id

    timestamps(type: :utc_datetime)
  end

  @valid_statuses ~w(active completed paused abandoned)

  @required_fields [:title]
  @optional_fields [:description, :status, :priority, :completed_at, :due_date, :metadata, :source_run_id, :review_schedule_id]

  def changeset(goal, attrs) do
    goal
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:title, max: 500)
    |> validate_length(:description, max: 10_000)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:agent_id)
    |> foreign_key_constraint(:source_run_id)
    |> foreign_key_constraint(:review_schedule_id)
  end

  def complete_changeset(goal) do
    goal
    |> change(status: "completed", completed_at: DateTime.utc_now(:second))
  end

  def abandon_changeset(goal) do
    goal
    |> change(status: "abandoned", completed_at: DateTime.utc_now(:second))
  end
end
