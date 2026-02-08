defmodule OneAgent.Agents.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agents" do
    field :name, :string
    field :description, :string
    field :system_prompt, :string
    field :model_provider, :string
    field :model_id, :string
    field :model_config, :map, default: %{}
    field :max_steps_per_run, :integer, default: 50
    field :max_runs_per_day, :integer, default: 100
    field :max_history_messages, :integer, default: 20

    belongs_to :user, OneAgent.Accounts.User
    belongs_to :llm_config, OneAgent.Credentials.LlmConfig
    has_many :buckets, OneAgent.Agents.AgentBucket
    has_many :runs, OneAgent.Agents.AgentRun
    has_many :memories, OneAgent.Agents.AgentMemory
    has_many :messages, OneAgent.Agents.AgentMessage
    has_many :schedules, OneAgent.Agents.AgentSchedule
    has_many :goals, OneAgent.Agents.AgentGoal

    timestamps(type: :utc_datetime)
  end

  @valid_providers ~w(anthropic openai)

  @required_fields [:name, :system_prompt, :model_provider, :model_id]
  @optional_fields [
    :description, :model_config,
    :max_steps_per_run, :max_runs_per_day, :max_history_messages, :llm_config_id
  ]

  @allowed_model_config_keys ~w(max_tokens)

  def changeset(agent, attrs) do
    agent
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, max: 10_000)
    |> validate_length(:system_prompt, max: 100_000)
    |> validate_length(:model_id, max: 255)
    |> validate_inclusion(:model_provider, @valid_providers)
    |> validate_number(:max_steps_per_run, greater_than: 0, less_than_or_equal_to: 500)
    |> validate_number(:max_runs_per_day, greater_than: 0, less_than_or_equal_to: 10_000)
    |> validate_number(:max_history_messages, greater_than_or_equal_to: 0, less_than_or_equal_to: 200)
    |> validate_model_config()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:llm_config_id)
  end

  defp validate_model_config(changeset) do
    case get_change(changeset, :model_config) do
      nil ->
        changeset

      config when is_map(config) ->
        unknown_keys = Map.keys(config) -- @allowed_model_config_keys
        cond do
          unknown_keys != [] ->
            add_error(changeset, :model_config, "contains unknown keys: #{Enum.join(unknown_keys, ", ")}")

          Map.has_key?(config, "max_tokens") and not valid_max_tokens?(config["max_tokens"]) ->
            add_error(changeset, :model_config, "max_tokens must be an integer between 1 and 100000")

          true ->
            changeset
        end

      _other ->
        add_error(changeset, :model_config, "must be a map")
    end
  end

  defp valid_max_tokens?(value) when is_integer(value), do: value >= 1 and value <= 100_000
  defp valid_max_tokens?(_), do: false
end
