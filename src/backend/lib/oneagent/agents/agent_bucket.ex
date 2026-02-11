defmodule OneAgent.Agents.AgentBucket do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agent_buckets" do
    field :bucket, :string
    field :scope_config, :map, default: %{}
    field :granted_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :agent, OneAgent.Agents.Agent
    belongs_to :credential, OneAgent.Credentials.Credential

    timestamps(type: :utc_datetime)
  end

  @valid_buckets ~w(web_access email spending communication data_write gmail web_search google_calendar whatsapp telegram)

  def valid_buckets, do: @valid_buckets

  def changeset(bucket, attrs) do
    bucket
    |> cast(attrs, [:bucket, :scope_config, :credential_id])
    |> validate_required([:bucket])
    |> validate_inclusion(:bucket, @valid_buckets)
    |> put_granted_at()
    |> foreign_key_constraint(:agent_id)
    |> foreign_key_constraint(:credential_id)
    |> unique_constraint([:agent_id, :bucket], name: :agent_buckets_active_unique)
  end

  defp put_granted_at(changeset) do
    if get_change(changeset, :granted_at) do
      changeset
    else
      put_change(changeset, :granted_at, DateTime.utc_now(:second))
    end
  end

  def revoke_changeset(bucket) do
    change(bucket, revoked_at: DateTime.utc_now(:second))
  end
end
