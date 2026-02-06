defmodule OneAgent.Repo.Migrations.CreateAgentMessages do
  use Ecto.Migration

  def change do
    create table(:agent_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false
      add :content, :text, null: false
      add :sequence, :integer, null: false
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :run_id, references(:agent_runs, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:agent_messages, [:agent_id])
    create index(:agent_messages, [:agent_id, :sequence])

    alter table(:agents) do
      add :max_history_messages, :integer, default: 20, null: false
    end
  end
end
