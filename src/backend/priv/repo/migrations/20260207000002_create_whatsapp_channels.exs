defmodule OneAgent.Repo.Migrations.CreateWhatsappChannels do
  use Ecto.Migration

  def change do
    create table(:whatsapp_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :credential_id, references(:credentials, type: :binary_id, on_delete: :restrict), null: false
      add :phone_number_id, :string, null: false
      add :verify_token, :string, null: false
      add :display_phone_number, :string
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:whatsapp_channels, [:phone_number_id])
    create index(:whatsapp_channels, [:user_id])
    create index(:whatsapp_channels, [:agent_id])
  end
end
