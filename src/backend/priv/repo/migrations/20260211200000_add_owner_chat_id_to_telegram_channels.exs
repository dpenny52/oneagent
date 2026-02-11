defmodule OneAgent.Repo.Migrations.AddOwnerChatIdToTelegramChannels do
  use Ecto.Migration

  def change do
    alter table(:telegram_channels) do
      add :owner_chat_id, :string
    end
  end
end
