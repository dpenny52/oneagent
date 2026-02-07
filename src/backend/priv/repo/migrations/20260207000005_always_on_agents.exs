defmodule OneAgent.Repo.Migrations.AlwaysOnAgents do
  use Ecto.Migration

  def up do
    # 1. Create agent_schedules table
    create table(:agent_schedules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :cron, :string, null: false
      add :message, :text
      add :enabled, :boolean, default: true, null: false
      add :last_run_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:agent_schedules, [:agent_id])

    # 2. Data migration: copy existing trigger_config into agent_schedules
    execute """
    INSERT INTO agent_schedules (id, agent_id, cron, message, enabled, inserted_at, updated_at)
    SELECT gen_random_uuid(), id, trigger_config->>'cron', trigger_config->>'message', true, NOW(), NOW()
    FROM agents
    WHERE trigger_type = 'scheduled' AND trigger_config->>'cron' IS NOT NULL
    """

    # 3. Drop columns from agents
    alter table(:agents) do
      remove :status
      remove :trigger_type
      remove :trigger_config
    end
  end

  def down do
    alter table(:agents) do
      add :status, :string, default: "created"
      add :trigger_type, :string, default: "on_demand"
      add :trigger_config, :map, default: %{}
    end

    drop table(:agent_schedules)
  end
end
