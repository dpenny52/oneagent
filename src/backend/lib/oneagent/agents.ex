defmodule OneAgent.Agents do
  @moduledoc """
  The Agents context. Manages agent CRUD, permission buckets,
  execution history (runs/steps), persistent memory, and schedules.

  All queries are scoped to the authenticated user via scope.
  """

  import Ecto.Query
  alias OneAgent.Repo
  alias OneAgent.Agents.{Agent, AgentBucket, AgentRun, AgentStep, AgentMemory, AgentMessage, AgentSchedule, AgentGoal, AgentGoalStep}

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

  def count_memories(%Agent{} = agent) do
    Repo.one(from m in AgentMemory, where: m.agent_id == ^agent.id, select: count(m.id))
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

  @doc """
  Full-text search across an agent's memories using PostgreSQL tsvector.

  Uses `websearch_to_tsquery` for Google-style query syntax:
  - Quoted phrases: "exact phrase"
  - OR: term1 OR term2
  - Exclusion: -term

  Results are ranked with key matches weighted highest (A), value matches
  medium (B), and memory_type matches lowest (C).

  Options:
    * `:limit` — max results (default 20)
  """
  def search_memories(%Agent{} = agent, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    from(m in AgentMemory,
      where: m.agent_id == ^agent.id,
      where: is_nil(m.expires_at) or m.expires_at > ^DateTime.utc_now(),
      where: fragment("search_ts @@ websearch_to_tsquery('english', ?)", ^query),
      order_by: [desc: fragment("ts_rank_cd(search_ts, websearch_to_tsquery('english', ?), 32)", ^query)],
      limit: ^limit,
      select: %{
        memory: m,
        rank: fragment("ts_rank_cd(search_ts, websearch_to_tsquery('english', ?), 32)", ^query)
      }
    )
    |> Repo.all()
  end

  # ── Messages (Chat History) ────────────────────────────────

  @doc """
  Messages for the chat API / display. Excludes scheduled user messages
  (system triggers) but includes scheduled assistant messages (agent responses).
  """
  def list_messages_for_display(%Agent{} = agent, opts \\ []) do
    limit = Keyword.get(opts, :limit) || agent.max_history_messages

    subquery =
      from m in AgentMessage,
        where: m.agent_id == ^agent.id,
        where: not (m.source == "scheduled" and m.role == "user"),
        order_by: [desc: m.sequence],
        limit: ^limit

    from(m in subquery(subquery), order_by: [asc: m.sequence])
    |> Repo.all()
  end

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

  def count_schedules(%Agent{} = agent) do
    Repo.one(from s in AgentSchedule, where: s.agent_id == ^agent.id, select: count(s.id))
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

  # ── Goals ──────────────────────────────────────────────────

  def list_goals(%Agent{} = agent, opts \\ []) do
    status = Keyword.get(opts, :status)

    query =
      from(g in AgentGoal,
        where: g.agent_id == ^agent.id,
        preload: [steps: ^from(s in AgentGoalStep, order_by: s.position), review_schedule: ^from(rs in AgentSchedule)],
        order_by: [desc: g.priority, asc: g.inserted_at]
      )

    query =
      if status do
        where(query, [g], g.status == ^status)
      else
        query
      end

    Repo.all(query)
  end

  def get_goal(%Agent{} = agent, goal_id) do
    query =
      from(g in AgentGoal,
        where: g.id == ^goal_id and g.agent_id == ^agent.id,
        preload: [steps: ^from(s in AgentGoalStep, order_by: s.position), review_schedule: ^from(rs in AgentSchedule)]
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      goal -> {:ok, goal}
    end
  end

  def count_goals(%Agent{} = agent, status) do
    Repo.one(from g in AgentGoal, where: g.agent_id == ^agent.id and g.status == ^status, select: count(g.id))
  end

  def create_goal(%Agent{} = agent, attrs) do
    %AgentGoal{agent_id: agent.id}
    |> AgentGoal.changeset(attrs)
    |> Repo.insert()
  end

  def update_goal(%AgentGoal{} = goal, attrs) do
    goal
    |> AgentGoal.changeset(attrs)
    |> Repo.update()
  end

  def complete_goal(%AgentGoal{} = goal) do
    Repo.transaction(fn ->
      # Update pending/in_progress steps to completed
      from(s in AgentGoalStep,
        where: s.goal_id == ^goal.id and s.status in ["pending", "in_progress"]
      )
      |> Repo.update_all(set: [status: "completed", completed_at: DateTime.utc_now(:second)])

      # Mark goal as completed
      {:ok, updated_goal} =
        goal
        |> AgentGoal.complete_changeset()
        |> Repo.update()

      # Disable all associated schedules
      disable_goal_schedules(updated_goal)

      updated_goal
    end)
  end

  def abandon_goal(%AgentGoal{} = goal) do
    Repo.transaction(fn ->
      # Update pending/in_progress steps to skipped
      from(s in AgentGoalStep,
        where: s.goal_id == ^goal.id and s.status in ["pending", "in_progress"]
      )
      |> Repo.update_all(set: [status: "skipped"])

      # Mark goal as abandoned
      {:ok, updated_goal} =
        goal
        |> AgentGoal.abandon_changeset()
        |> Repo.update()

      # Disable all associated schedules
      disable_goal_schedules(updated_goal)

      updated_goal
    end)
  end

  def delete_goal(%AgentGoal{} = goal) do
    # Preload to get schedule IDs for cleanup
    goal = Repo.preload(goal, steps: from(s in AgentGoalStep, select: s))

    Repo.transaction(fn ->
      # Delete step-linked schedules
      step_schedule_ids =
        goal.steps
        |> Enum.map(& &1.schedule_id)
        |> Enum.reject(&is_nil/1)

      if step_schedule_ids != [] do
        from(s in AgentSchedule, where: s.id in ^step_schedule_ids)
        |> Repo.delete_all()
      end

      # Delete review schedule
      if goal.review_schedule_id do
        from(s in AgentSchedule, where: s.id == ^goal.review_schedule_id)
        |> Repo.delete_all()
      end

      # Delete goal (cascades to steps via FK)
      {:ok, deleted} = Repo.delete(goal)
      deleted
    end)
  end

  # ── Goal Steps ─────────────────────────────────────────────

  def create_goal_step(%AgentGoal{} = goal, attrs) do
    position = next_step_position(goal)

    %AgentGoalStep{goal_id: goal.id}
    |> AgentGoalStep.changeset(Map.put(attrs, :position, position))
    |> Repo.insert()
  end

  def update_goal_step(%AgentGoalStep{} = step, attrs) do
    step
    |> AgentGoalStep.changeset(attrs)
    |> Repo.update()
  end

  def delete_goal_step(%AgentGoalStep{} = step) do
    Repo.transaction(fn ->
      # Clean up linked schedule if present
      if step.schedule_id do
        case Repo.get(AgentSchedule, step.schedule_id) do
          nil -> :ok
          schedule -> Repo.delete(schedule)
        end
      end

      {:ok, deleted} = Repo.delete(step)
      deleted
    end)
  end

  def get_goal_step(%AgentGoal{} = goal, step_id) do
    case Ecto.UUID.cast(step_id) do
      {:ok, _uuid} ->
        case Repo.get_by(AgentGoalStep, id: step_id, goal_id: goal.id) do
          nil -> {:error, :not_found}
          step -> {:ok, step}
        end

      :error ->
        # LLMs sometimes pass position number instead of UUID — fall back to position lookup
        case Integer.parse(to_string(step_id)) do
          {position, ""} ->
            case Repo.get_by(AgentGoalStep, position: position, goal_id: goal.id) do
              nil -> {:error, :not_found}
              step -> {:ok, step}
            end

          _ ->
            {:error, :not_found}
        end
    end
  end

  def get_step_by_schedule(schedule_id) do
    from(s in AgentGoalStep,
      where: s.schedule_id == ^schedule_id and s.status in ["pending", "in_progress"],
      preload: [goal: ^from(g in AgentGoal)]
    )
    |> Repo.one()
  end

  def get_goal_by_review_schedule(schedule_id) do
    from(g in AgentGoal,
      where: g.review_schedule_id == ^schedule_id and g.status == "active"
    )
    |> Repo.one()
  end

  def create_step_with_schedule(%AgentGoal{} = goal, step_attrs, schedule_attrs) do
    Repo.transaction(fn ->
      # Create the schedule first
      {:ok, schedule} = create_schedule(%Agent{id: goal.agent_id}, schedule_attrs)

      # Create the step linked to the schedule
      position = next_step_position(goal)
      step_attrs = step_attrs |> Map.put(:position, position) |> Map.put(:schedule_id, schedule.id)

      case %AgentGoalStep{goal_id: goal.id}
           |> AgentGoalStep.changeset(step_attrs)
           |> Repo.insert() do
        {:ok, step} -> step
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def disable_goal_schedules(%AgentGoal{} = goal) do
    # Disable review schedule
    if goal.review_schedule_id do
      from(s in AgentSchedule, where: s.id == ^goal.review_schedule_id)
      |> Repo.update_all(set: [enabled: false])
    end

    # Disable step-linked schedules
    goal_with_steps = Repo.preload(goal, steps: from(s in AgentGoalStep, select: s))

    step_schedule_ids =
      goal_with_steps.steps
      |> Enum.map(& &1.schedule_id)
      |> Enum.reject(&is_nil/1)

    if step_schedule_ids != [] do
      from(s in AgentSchedule, where: s.id in ^step_schedule_ids)
      |> Repo.update_all(set: [enabled: false])
    end
  end

  defp next_step_position(%AgentGoal{} = goal) do
    case Repo.one(from s in AgentGoalStep, where: s.goal_id == ^goal.id, select: max(s.position)) do
      nil -> 1
      max_pos -> max_pos + 1
    end
  end
end
