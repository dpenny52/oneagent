defmodule OneAgent.Repo.Migrations.CreateAgentGoals do
  use Ecto.Migration

  def change do
    create table(:agent_goals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "active"
      add :priority, :integer, null: false, default: 0
      add :source_run_id, references(:agent_runs, type: :binary_id, on_delete: :nilify_all)
      add :review_schedule_id, references(:agent_schedules, type: :binary_id, on_delete: :nilify_all)
      add :completed_at, :utc_datetime
      add :due_date, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:agent_goals, [:agent_id])
    create index(:agent_goals, [:agent_id, :status])
    create index(:agent_goals, [:review_schedule_id])

    create table(:agent_goal_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :goal_id, references(:agent_goals, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "pending"
      add :position, :integer, null: false
      add :schedule_id, references(:agent_schedules, type: :binary_id, on_delete: :nilify_all)
      add :completed_at, :utc_datetime
      add :result_notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:agent_goal_steps, [:goal_id])
    create index(:agent_goal_steps, [:goal_id, :position])
    create index(:agent_goal_steps, [:schedule_id])
  end
end
