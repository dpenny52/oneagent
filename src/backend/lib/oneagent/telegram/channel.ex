defmodule OneAgent.Telegram.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "telegram_channels" do
    field :bot_id, :string
    field :secret_token, :string
    field :bot_username, :string
    field :active, :boolean, default: true
    field :webhook_registered, :boolean, default: false
    field :owner_chat_id, :string

    belongs_to :user, OneAgent.Accounts.User
    belongs_to :agent, OneAgent.Agents.Agent
    belongs_to :credential, OneAgent.Credentials.Credential

    timestamps(type: :utc_datetime)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:agent_id, :credential_id, :bot_id, :bot_username, :active])
    |> validate_required([:agent_id, :credential_id, :bot_id])
    |> validate_length(:bot_id, min: 1, max: 255)
    |> maybe_generate_secret_token()
    |> unique_constraint(:bot_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:agent_id)
    |> foreign_key_constraint(:credential_id)
  end

  def update_changeset(channel, attrs) do
    channel
    |> cast(attrs, [:agent_id, :credential_id, :bot_username, :active, :webhook_registered, :owner_chat_id])
    |> foreign_key_constraint(:agent_id)
    |> foreign_key_constraint(:credential_id)
  end

  defp maybe_generate_secret_token(changeset) do
    case get_field(changeset, :secret_token) do
      nil -> put_change(changeset, :secret_token, generate_secret_token())
      _ -> changeset
    end
  end

  defp generate_secret_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
