defmodule OneAgent.Repo.Migrations.AddSourceToAgentMessages do
  use Ecto.Migration

  def change do
    alter table(:agent_messages) do
      add :source, :string, null: false, default: "chat"
    end

    create index(:agent_messages, [:agent_id, :source, :sequence])
  end
end
