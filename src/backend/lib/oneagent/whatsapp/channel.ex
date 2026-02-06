defmodule OneAgent.WhatsApp.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "whatsapp_channels" do
    field :phone_number_id, :string
    field :verify_token, :string
    field :display_phone_number, :string
    field :active, :boolean, default: true

    belongs_to :user, OneAgent.Accounts.User
    belongs_to :agent, OneAgent.Agents.Agent
    belongs_to :credential, OneAgent.Credentials.Credential

    timestamps(type: :utc_datetime)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:agent_id, :credential_id, :phone_number_id, :verify_token, :display_phone_number, :active])
    |> validate_required([:agent_id, :credential_id, :phone_number_id])
    |> validate_length(:phone_number_id, min: 1, max: 255)
    |> maybe_generate_verify_token()
    |> unique_constraint(:phone_number_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:agent_id)
    |> foreign_key_constraint(:credential_id)
  end

  def update_changeset(channel, attrs) do
    channel
    |> cast(attrs, [:agent_id, :credential_id, :display_phone_number, :active])
    |> foreign_key_constraint(:agent_id)
    |> foreign_key_constraint(:credential_id)
  end

  defp maybe_generate_verify_token(changeset) do
    case get_field(changeset, :verify_token) do
      nil -> put_change(changeset, :verify_token, generate_verify_token())
      _ -> changeset
    end
  end

  defp generate_verify_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
