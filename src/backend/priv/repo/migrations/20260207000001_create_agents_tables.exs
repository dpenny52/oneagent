defmodule OneAgent.Repo.Migrations.CreateAgentsTables do
  use Ecto.Migration

  def change do
    # Credentials (user-level, encrypted)
    create table(:credentials, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :service, :string, null: false
      add :credential_type, :string, null: false
      add :encrypted_value, :binary, null: false
      add :metadata, :map, default: %{}
      add :expires_at, :utc_datetime
      add :last_used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:credentials, [:user_id])
    create unique_index(:credentials, [:user_id, :name])

    # LLM configs (user-level, encrypted API keys)
    create table(:llm_configs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :encrypted_api_key, :binary, null: false
      add :label, :string, null: false
      add :is_default, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:llm_configs, [:user_id])
    create unique_index(:llm_configs, [:user_id, :label])

    # Agents
    create table(:agents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :system_prompt, :text, null: false
      add :status, :string, null: false, default: "created"
      add :model_provider, :string, null: false
      add :model_id, :string, null: false
      add :model_config, :map, default: %{}
      add :trigger_type, :string, null: false, default: "on_demand"
      add :trigger_config, :map, default: %{}
      add :max_steps_per_run, :integer, null: false, default: 50
      add :max_runs_per_day, :integer, null: false, default: 100
      add :llm_config_id, references(:llm_configs, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:agents, [:user_id])
    create index(:agents, [:status])

    # Agent permission buckets
    create table(:agent_buckets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :bucket, :string, null: false
      add :scope_config, :map, default: %{}
      add :credential_id, references(:credentials, type: :binary_id, on_delete: :nilify_all)
      add :granted_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:agent_buckets, [:agent_id])
    create unique_index(:agent_buckets, [:agent_id, :bucket],
      where: "revoked_at IS NULL",
      name: :agent_buckets_active_unique
    )

    # Agent runs (execution history)
    create table(:agent_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"
      add :trigger, :string, null: false
      add :trigger_payload, :map, default: %{}
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :total_tokens_used, :integer, default: 0
      add :total_steps, :integer, default: 0
      add :error_message, :text

      timestamps(type: :utc_datetime)
    end

    create index(:agent_runs, [:agent_id])
    create index(:agent_runs, [:status])
    create index(:agent_runs, [:agent_id, :inserted_at])

    # Agent steps (individual LLM calls and tool executions)
    create table(:agent_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, references(:agent_runs, type: :binary_id, on_delete: :delete_all), null: false
      add :step_number, :integer, null: false
      add :step_type, :string, null: false
      add :input, :map, default: %{}
      add :output, :map, default: %{}
      add :tool_id, :string
      add :bucket, :string
      add :tokens_used, :integer, default: 0
      add :duration_ms, :integer
      add :status, :string, null: false, default: "completed"

      timestamps(type: :utc_datetime)
    end

    create index(:agent_steps, [:run_id])
    create index(:agent_steps, [:run_id, :step_number])

    # Agent memories (persistent knowledge)
    create table(:agent_memories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :value, :map, null: false
      add :memory_type, :string, null: false
      add :source_run_id, references(:agent_runs, type: :binary_id, on_delete: :nilify_all)
      add :confidence, :float, default: 1.0
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:agent_memories, [:agent_id])
    create unique_index(:agent_memories, [:agent_id, :key])
    create index(:agent_memories, [:agent_id, :memory_type])
  end
end
