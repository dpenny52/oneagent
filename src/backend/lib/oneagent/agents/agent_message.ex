defmodule OneAgent.Agents.AgentMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agent_messages" do
    field :role, :string
    field :content, :string
    field :sequence, :integer
    field :source, :string, default: "chat"

    belongs_to :agent, OneAgent.Agents.Agent
    belongs_to :run, OneAgent.Agents.AgentRun

    timestamps(type: :utc_datetime)
  end

  @required_fields [:role, :content, :sequence]
  @optional_fields [:run_id, :source]

  def changeset(message, attrs) do
    message
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:role, ~w(user assistant))
    |> validate_inclusion(:source, ~w(chat webhook scheduled telegram whatsapp))
    |> validate_length(:content, max: 32_000)
    |> foreign_key_constraint(:agent_id)
    |> foreign_key_constraint(:run_id)
  end
end
