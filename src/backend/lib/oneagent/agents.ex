defmodule OneAgent.Agents do
  @moduledoc """
  The Agents context. Manages agent CRUD, permission buckets,
  execution history (runs/steps), persistent memory, and schedules.

  All queries are scoped to the authenticated user via scope.
  """

  import Ecto.Query
  alias OneAgent.Repo
  alias OneAgent.Agents.{Agent, AgentBucket, AgentRun, AgentStep, AgentMemory, AgentMessage, AgentSchedule}

  # ── Agents CRUD ──────────────────────────────────────────────

  def list_agents(%{user: user}) do
    Agent
    |> where(user_id: ^user.id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def get_agent(%{user: user}, id) do
    case Repo.get_by(Agent, id: id, user_id: user.id) do
      nil -> {:error, :not_found}
      agent -> {:ok, agent}
    end
  end

  def create_agent(%{user: user}, attrs) do
    %Agent{user_id: user.id}
    |> Agent.changeset(attrs)
    |> Repo.insert()
  end

  def update_agent(%Agent{} = agent, attrs) do
    agent
    |> Agent.changeset(attrs)
    |> Repo.update()
  end

  def delete_agent(%Agent{} = agent) do
    Repo.delete(agent)
  end

  # ── Permission Buckets ───────────────────────────────────────

  def list_active_buckets(%Agent{} = agent) do
    AgentBucket
    |> where(agent_id: ^agent.id)
    |> where([b], is_nil(b.revoked_at))
    |> Repo.all()
  end

  def grant_bucket(%Agent{} = agent, attrs) do
    %AgentBucket{agent_id: agent.id}
    |> AgentBucket.changeset(attrs)
    |> Repo.insert()
  end

  def revoke_bucket(%Agent{} = agent, bucket_name) do
    query =
      from b in AgentBucket,
        where: b.agent_id == ^agent.id and b.bucket == ^bucket_name and is_nil(b.revoked_at)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      bucket ->
        bucket
        |> AgentBucket.revoke_changeset()
        |> Repo.update()
    end
  end

  def update_buckets(%Agent{} = agent, bucket_configs, scope) do
    alias OneAgent.Credentials

    # Validate all credential_ids belong to the current user
    invalid_credential =
      Enum.find(bucket_configs, fn config ->
        case Map.get(config, :credential_id) do
          nil -> false
          cred_id -> match?({:error, :not_found}, Credentials.get_credential(scope, cred_id))
        end
      end)

    if invalid_credential do
      {:error, :invalid_credential}
    else
      Repo.transaction(fn ->
        # Revoke all current active buckets
        from(b in AgentBucket, where: b.agent_id == ^agent.id and is_nil(b.revoked_at))
        |> Repo.update_all(set: [revoked_at: DateTime.utc_now(:second)])

        # Grant new buckets
        Enum.map(bucket_configs, fn config ->
          case grant_bucket(agent, config) do
            {:ok, bucket} -> bucket
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)
      end)
    end
  end

  def has_bucket?(%Agent{} = agent, bucket_name) do
    AgentBucket
    |> where(agent_id: ^agent.id, bucket: ^bucket_name)
    |> where([b], is_nil(b.revoked_at))
    |> Repo.exists?()
  end

  def get_bucket_with_credential(%Agent{} = agent, bucket_name) do
    AgentBucket
    |> where(agent_id: ^agent.id, bucket: ^bucket_name)
    |> where([b], is_nil(b.revoked_at))
    |> preload(:credential)
    |> Repo.one()
  end

  # ── Runs ─────────────────────────────────────────────────────

  def list_runs(%Agent{} = agent, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    AgentRun
    |> where(agent_id: ^agent.id)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_run(%Agent{} = agent, run_id) do
    case Repo.get_by(AgentRun, id: run_id, agent_id: agent.id) do
      nil -> {:error, :not_found}
      run -> {:ok, run}
    end
  end

  def get_run_with_steps(%Agent{} = agent, run_id) do
    query =
      from r in AgentRun,
        where: r.id == ^run_id and r.agent_id == ^agent.id,
        preload: [steps: ^from(s in AgentStep, order_by: s.step_number)]

    case Repo.one(query) do
      nil -> {:error, :not_found}
      run -> {:ok, run}
    end
  end

  def create_run(%Agent{} = agent, attrs) do
    %AgentRun{agent_id: agent.id}
    |> AgentRun.changeset(attrs)
    |> Repo.insert()
  end

  def start_run(%AgentRun{} = run) do
    run |> AgentRun.start_changeset() |> Repo.update()
  end

  def complete_run(%AgentRun{} = run, attrs \\ %{}) do
    run |> AgentRun.complete_changeset(attrs) |> Repo.update()
  end

  def fail_run(%AgentRun{} = run, error_message) do
    run |> AgentRun.fail_changeset(error_message) |> Repo.update()
  end

  def count_runs_today(%Agent{} = agent) do
    today_start = DateTime.utc_now() |> DateTime.to_date() |> DateTime.new!(~T[00:00:00])

    AgentRun
    |> where(agent_id: ^agent.id)
    |> where([r], r.inserted_at >= ^today_start)
    |> Repo.aggregate(:count)
  end

  # ── Steps ────────────────────────────────────────────────────

  def create_step(%AgentRun{} = run, attrs) do
    %AgentStep{run_id: run.id}
    |> AgentStep.changeset(attrs)
    |> Repo.insert()
  end

  # ── Memory ───────────────────────────────────────────────────

  def list_memories(%Agent{} = agent) do
    AgentMemory
    |> where(agent_id: ^agent.id)
    |> where([m], is_nil(m.expires_at) or m.expires_at > ^DateTime.utc_now())
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  def get_memory(%Agent{} = agent, key) do
    AgentMemory
    |> where(agent_id: ^agent.id, key: ^key)
    |> where([m], is_nil(m.expires_at) or m.expires_at > ^DateTime.utc_now())
    |> Repo.one()
  end

  def upsert_memory(%Agent{} = agent, attrs) do
    attrs = Map.put(attrs, :agent_id, agent.id)

    %AgentMemory{agent_id: agent.id}
    |> AgentMemory.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:value, :memory_type, :confidence, :expires_at, :source_run_id, :updated_at]},
      conflict_target: [:agent_id, :key]
    )
  end

  def delete_memory(%Agent{} = agent, key) do
    case get_memory(agent, key) do
      nil -> {:error, :not_found}
      memory -> Repo.delete(memory)
    end
  end

  def delete_all_memories(%Agent{} = agent) do
    from(m in AgentMemory, where: m.agent_id == ^agent.id)
    |> Repo.delete_all()
  end

  # ── Messages (Chat History) ────────────────────────────────

  def list_recent_messages(%Agent{} = agent, opts \\ []) do
    limit = Keyword.get(opts, :limit) || agent.max_history_messages
    exclude_sources = Keyword.get(opts, :exclude_sources, ["scheduled"])

    subquery =
      from m in AgentMessage,
        where: m.agent_id == ^agent.id,
        where: m.source not in ^exclude_sources,
        order_by: [desc: m.sequence],
        limit: ^limit

    from(m in subquery(subquery), order_by: [asc: m.sequence])
    |> Repo.all()
  end

  def create_message(%Agent{} = agent, attrs) do
    seq = next_message_sequence(agent)

    %AgentMessage{agent_id: agent.id}
    |> AgentMessage.changeset(Map.put(attrs, :sequence, seq))
    |> Repo.insert()
  end

  def delete_all_messages(%Agent{} = agent) do
    from(m in AgentMessage, where: m.agent_id == ^agent.id)
    |> Repo.delete_all()
  end

  defp next_message_sequence(%Agent{} = agent) do
    case Repo.one(from m in AgentMessage, where: m.agent_id == ^agent.id, select: max(m.sequence)) do
      nil -> 1
      max_seq -> max_seq + 1
    end
  end

  # ── Schedules ───────────────────────────────────────────────

  def list_schedules(%Agent{} = agent) do
    AgentSchedule
    |> where(agent_id: ^agent.id)
    |> order_by(asc: :inserted_at)
    |> Repo.all()
  end

  def get_schedule(%Agent{} = agent, schedule_id) do
    case Repo.get_by(AgentSchedule, id: schedule_id, agent_id: agent.id) do
      nil -> {:error, :not_found}
      schedule -> {:ok, schedule}
    end
  end

  def create_schedule(%Agent{} = agent, attrs) do
    %AgentSchedule{agent_id: agent.id}
    |> AgentSchedule.changeset(attrs)
    |> Repo.insert()
  end

  def update_schedule(%AgentSchedule{} = schedule, attrs) do
    schedule
    |> AgentSchedule.changeset(attrs)
    |> Repo.update()
  end

  def delete_schedule(%AgentSchedule{} = schedule) do
    Repo.delete(schedule)
  end

  def update_schedule_last_run(%AgentSchedule{} = schedule) do
    schedule
    |> Ecto.Changeset.change(last_run_at: DateTime.utc_now(:second))
    |> Repo.update()
  end

  @doc """
  Returns all enabled schedules joined with their agents,
  filtered to agents that have an llm_config_id set.
  """
  def list_enabled_schedules do
    from(s in AgentSchedule,
      join: a in assoc(s, :agent),
      where: s.enabled == true and not is_nil(a.llm_config_id),
      preload: [agent: a]
    )
    |> Repo.all()
  end
end
