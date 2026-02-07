defmodule OneAgent.Credentials.LlmConfig do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "llm_configs" do
    field :provider, :string
    field :encrypted_api_key, OneAgent.Encrypted.Binary
    field :api_key, :string, virtual: true, redact: true
    field :label, :string
    field :is_default, :boolean, default: false

    belongs_to :user, OneAgent.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @valid_providers ~w(anthropic openai)

  def changeset(config, attrs) do
    config
    |> cast(attrs, [:provider, :api_key, :label, :is_default])
    |> validate_required([:provider, :api_key, :label])
    |> validate_inclusion(:provider, @valid_providers)
    |> validate_length(:label, min: 1, max: 255)
    |> encrypt_api_key()
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :label])
  end

  def update_changeset(config, attrs) do
    config
    |> cast(attrs, [:provider, :api_key, :label, :is_default])
    |> validate_inclusion(:provider, @valid_providers)
    |> encrypt_api_key()
    |> unique_constraint([:user_id, :label])
  end

  defp encrypt_api_key(changeset) do
    case get_change(changeset, :api_key) do
      nil -> changeset
      key -> put_change(changeset, :encrypted_api_key, key)
    end
  end
end
