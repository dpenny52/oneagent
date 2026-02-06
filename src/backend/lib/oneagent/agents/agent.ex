defmodule OneAgent.Agents.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agents" do
    field :name, :string
    field :description, :string
    field :system_prompt, :string
    field :status, :string, default: "created"
    field :model_provider, :string
    field :model_id, :string
    field :model_config, :map, default: %{}
    field :trigger_type, :string, default: "on_demand"
    field :trigger_config, :map, default: %{}
    field :max_steps_per_run, :integer, default: 50
    field :max_runs_per_day, :integer, default: 100

    belongs_to :user, OneAgent.Accounts.User
    belongs_to :llm_config, OneAgent.Credentials.LlmConfig
    has_many :buckets, OneAgent.Agents.AgentBucket
    has_many :runs, OneAgent.Agents.AgentRun
    has_many :memories, OneAgent.Agents.AgentMemory

    timestamps(type: :utc_datetime)
  end

  @valid_statuses ~w(created configured running paused stopped)
  @valid_providers ~w(anthropic openai)
  @valid_triggers ~w(on_demand scheduled webhook continuous)

  @required_fields [:name, :system_prompt, :model_provider, :model_id]
  @optional_fields [
    :description, :status, :model_config, :trigger_type,
    :trigger_config, :max_steps_per_run, :max_runs_per_day, :llm_config_id
  ]

  def changeset(agent, attrs) do
    agent
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:model_provider, @valid_providers)
    |> validate_inclusion(:trigger_type, @valid_triggers)
    |> validate_number(:max_steps_per_run, greater_than: 0, less_than_or_equal_to: 500)
    |> validate_number(:max_runs_per_day, greater_than: 0, less_than_or_equal_to: 10_000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:llm_config_id)
  end

  def status_changeset(agent, status) do
    agent
    |> change(status: status)
    |> validate_inclusion(:status, @valid_statuses)
  end
end
