defmodule OneAgent.Credentials.Credential do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "credentials" do
    field :name, :string
    field :service, :string
    field :credential_type, :string
    field :encrypted_value, OneAgent.Encrypted.Binary
    field :value, :string, virtual: true, redact: true
    field :metadata, :map, default: %{}
    field :expires_at, :utc_datetime
    field :last_used_at, :utc_datetime

    belongs_to :user, OneAgent.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @valid_types ~w(api_key oauth_token basic_auth custom)

  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [:name, :service, :credential_type, :value, :metadata, :expires_at])
    |> validate_required([:name, :service, :credential_type, :value])
    |> validate_inclusion(:credential_type, @valid_types)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:service, min: 1, max: 255)
    |> encrypt_value()
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :name])
  end

  def update_changeset(credential, attrs) do
    credential
    |> cast(attrs, [:name, :service, :credential_type, :value, :metadata, :expires_at])
    |> validate_inclusion(:credential_type, @valid_types)
    |> maybe_encrypt_value()
    |> unique_constraint([:user_id, :name])
  end

  defp encrypt_value(changeset) do
    case get_change(changeset, :value) do
      nil -> changeset
      value -> put_change(changeset, :encrypted_value, value)
    end
  end

  defp maybe_encrypt_value(changeset) do
    case get_change(changeset, :value) do
      nil -> changeset
      value -> put_change(changeset, :encrypted_value, value)
    end
  end

  def touch_last_used(credential) do
    change(credential, last_used_at: DateTime.utc_now(:second))
  end
end
