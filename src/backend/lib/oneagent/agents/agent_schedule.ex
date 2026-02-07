defmodule OneAgent.Agents.AgentSchedule do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agent_schedules" do
    field :cron, :string
    field :message, :string
    field :enabled, :boolean, default: true
    field :last_run_at, :utc_datetime

    belongs_to :agent, OneAgent.Agents.Agent

    timestamps(type: :utc_datetime)
  end

  @required_fields [:cron]
  @optional_fields [:message, :enabled, :last_run_at]

  def changeset(schedule, attrs) do
    schedule
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_cron()
    |> foreign_key_constraint(:agent_id)
  end

  defp validate_cron(changeset) do
    case get_change(changeset, :cron) do
      nil -> changeset
      cron ->
        case Crontab.CronExpression.Parser.parse(cron) do
          {:ok, _} -> changeset
          {:error, _} -> add_error(changeset, :cron, "is not a valid cron expression")
        end
    end
  end
end
