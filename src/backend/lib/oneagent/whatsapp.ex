defmodule OneAgent.WhatsApp do
  @moduledoc """
  The WhatsApp context. Manages WhatsApp channel configuration
  linking phone numbers to agents.

  All CRUD queries are scoped to the authenticated user via scope.
  Webhook lookups are unscoped (used by the webhook handler).
  """

  import Ecto.Query
  alias OneAgent.Repo
  alias OneAgent.WhatsApp.Channel

  # ── Scoped CRUD ────────────────────────────────────────────

  def list_channels(%{user: user}) do
    Channel
    |> where(user_id: ^user.id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def get_channel(%{user: user}, id) do
    case Repo.get_by(Channel, id: id, user_id: user.id) do
      nil -> {:error, :not_found}
      channel -> {:ok, channel}
    end
  end

  def create_channel(%{user: user}, attrs) do
    with :ok <- validate_ownership(user, attrs) do
      %Channel{user_id: user.id}
      |> Channel.changeset(attrs)
      |> Repo.insert()
    end
  end

  def update_channel(%{user: user} = scope, %Channel{} = channel, attrs) do
    with :ok <- validate_ownership(user, attrs, scope, channel) do
      channel
      |> Channel.update_changeset(attrs)
      |> Repo.update()
    end
  end

  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
  end

  # ── Unscoped lookups (webhook handler) ─────────────────────

  @doc """
  Finds an active channel by Meta's phone_number_id.
  Preloads user, agent, and credential for the webhook handler.
  """
  def get_active_channel_by_phone_number_id(phone_number_id) do
    Channel
    |> where(phone_number_id: ^phone_number_id, active: true)
    |> preload([:user, :agent, :credential])
    |> Repo.one()
  end

  @doc """
  Finds a channel by its verify_token (used for Meta webhook verification GET).
  """
  def get_channel_by_verify_token(verify_token) do
    Repo.get_by(Channel, verify_token: verify_token)
  end

  @doc """
  Finds the first active channel for an agent (used by send_whatsapp tool).
  Returns the channel or nil.
  """
  def get_active_channel_by_agent_id(agent_id) do
    Channel
    |> where(agent_id: ^agent_id, active: true)
    |> limit(1)
    |> Repo.one()
  end

  # ── Ownership validation ───────────────────────────────────

  defp validate_ownership(user, attrs, scope \\ nil, channel \\ nil) do
    agent_id = Map.get(attrs, "agent_id") || Map.get(attrs, :agent_id)
    credential_id = Map.get(attrs, "credential_id") || Map.get(attrs, :credential_id)

    with :ok <- validate_agent_ownership(user, agent_id, scope, channel),
         :ok <- validate_credential_ownership(user, credential_id, scope, channel) do
      :ok
    end
  end

  defp validate_agent_ownership(_user, nil, _scope, nil), do: {:error, "agent_id is required"}
  defp validate_agent_ownership(_user, nil, _scope, _channel), do: :ok

  defp validate_agent_ownership(user, agent_id, _scope, _channel) do
    case OneAgent.Agents.get_agent(%{user: user}, agent_id) do
      {:ok, _agent} -> :ok
      {:error, :not_found} -> {:error, "Agent not found or not owned by you"}
    end
  end

  defp validate_credential_ownership(_user, nil, _scope, nil), do: {:error, "credential_id is required"}
  defp validate_credential_ownership(_user, nil, _scope, _channel), do: :ok

  defp validate_credential_ownership(user, credential_id, _scope, _channel) do
    case OneAgent.Credentials.get_credential(%{user: user}, credential_id) do
      {:ok, _cred} -> :ok
      {:error, :not_found} -> {:error, "Credential not found or not owned by you"}
    end
  end
end
