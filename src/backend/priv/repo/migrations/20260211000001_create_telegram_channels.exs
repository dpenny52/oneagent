defmodule OneAgent.Repo.Migrations.CreateTelegramChannels do
  use Ecto.Migration

  def change do
    create table(:telegram_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :credential_id, references(:credentials, type: :binary_id, on_delete: :restrict), null: false
      add :bot_id, :string, null: false
      add :secret_token, :string, null: false
      add :bot_username, :string
      add :active, :boolean, null: false, default: true
      add :webhook_registered, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:telegram_channels, [:bot_id])
    create index(:telegram_channels, [:user_id])
    create index(:telegram_channels, [:agent_id])
  end
end
