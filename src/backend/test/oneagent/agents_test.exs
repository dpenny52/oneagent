defmodule OneAgent.AgentsTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Agents
  alias OneAgent.Agents.{Agent, AgentBucket, AgentStep, AgentMemory, AgentSchedule}

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    %{scope: scope}
  end

  # ── Agent CRUD ───────────────────────────────────────────────

  describe "list_agents/1" do
    test "returns agents for the given user", %{scope: scope} do
      agent = agent_fixture(scope)
      assert [listed] = Agents.list_agents(scope)
      assert listed.id == agent.id
    end

    test "does not return agents from other users", %{scope: scope} do
      other_scope = user_scope_fixture()
      _other_agent = agent_fixture(other_scope)
      assert Agents.list_agents(scope) == []
    end
  end

  describe "get_agent/2" do
    test "returns the agent for the given user", %{scope: scope} do
      agent = agent_fixture(scope)
      assert {:ok, found} = Agents.get_agent(scope, agent.id)
      assert found.id == agent.id
    end

    test "returns error for agent from another user", %{scope: scope} do
      other_scope = user_scope_fixture()
      agent = agent_fixture(other_scope)
      assert {:error, :not_found} = Agents.get_agent(scope, agent.id)
    end
  end

  describe "create_agent/2" do
    test "creates an agent with valid attrs", %{scope: scope} do
      attrs = valid_agent_attributes()
      assert {:ok, %Agent{} = agent} = Agents.create_agent(scope, attrs)
      assert agent.name == attrs["name"]
      assert agent.model_provider == "anthropic"
    end

    test "fails with missing required fields", %{scope: scope} do
      assert {:error, changeset} = Agents.create_agent(scope, %{})
      assert %{name: _, system_prompt: _, model_provider: _, model_id: _} = errors_on(changeset)
    end

    test "fails with invalid model provider", %{scope: scope} do
      attrs = valid_agent_attributes(%{"model_provider" => "invalid"})
      assert {:error, changeset} = Agents.create_agent(scope, attrs)
      assert %{model_provider: _} = errors_on(changeset)
    end
  end

  describe "update_agent/2" do
    test "updates an agent", %{scope: scope} do
      agent = agent_fixture(scope)
      assert {:ok, updated} = Agents.update_agent(agent, %{"name" => "Updated Name"})
      assert updated.name == "Updated Name"
    end
  end

  describe "delete_agent/1" do
    test "deletes an agent", %{scope: scope} do
      agent = agent_fixture(scope)
      assert {:ok, _} = Agents.delete_agent(agent)
      assert {:error, :not_found} = Agents.get_agent(scope, agent.id)
    end
  end

  # ── Permission Buckets ───────────────────────────────────────

  describe "grant_bucket/2" do
    test "grants a bucket to an agent", %{scope: scope} do
      agent = agent_fixture(scope)
      assert {:ok, %AgentBucket{} = bucket} = Agents.grant_bucket(agent, %{bucket: "web_access"})
      assert bucket.bucket == "web_access"
      assert bucket.granted_at != nil
      assert bucket.revoked_at == nil
    end

    test "fails with invalid bucket name", %{scope: scope} do
      agent = agent_fixture(scope)
      assert {:error, changeset} = Agents.grant_bucket(agent, %{bucket: "invalid_bucket"})
      assert %{bucket: _} = errors_on(changeset)
    end
  end

  describe "revoke_bucket/2" do
    test "revokes an active bucket", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "web_access"})

      assert {:ok, revoked} = Agents.revoke_bucket(agent, "web_access")
      assert revoked.revoked_at != nil
    end

    test "returns error for non-existent bucket", %{scope: scope} do
      agent = agent_fixture(scope)
      assert {:error, :not_found} = Agents.revoke_bucket(agent, "web_access")
    end
  end

  describe "has_bucket?/2" do
    test "returns true for active bucket", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "email"})
      assert Agents.has_bucket?(agent, "email")
    end

    test "returns false for revoked bucket", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "email"})
      {:ok, _} = Agents.revoke_bucket(agent, "email")
      refute Agents.has_bucket?(agent, "email")
    end

    test "returns false for non-existent bucket", %{scope: scope} do
      agent = agent_fixture(scope)
      refute Agents.has_bucket?(agent, "email")
    end
  end

  # ── Runs ─────────────────────────────────────────────────────

  describe "runs" do
    test "create, start, complete flow", %{scope: scope} do
      agent = agent_fixture(scope)

      {:ok, run} = Agents.create_run(agent, %{trigger: "manual"})
      assert run.status == "pending"

      {:ok, run} = Agents.start_run(run)
      assert run.status == "running"
      assert run.started_at != nil

      {:ok, run} = Agents.complete_run(run, %{total_steps: 3, total_tokens_used: 500})
      assert run.status == "completed"
      assert run.completed_at != nil
      assert run.total_steps == 3
    end

    test "fail_run sets error message", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, run} = Agents.create_run(agent, %{trigger: "manual"})
      {:ok, run} = Agents.start_run(run)

      {:ok, run} = Agents.fail_run(run, "Something went wrong")
      assert run.status == "failed"
      assert run.error_message == "Something went wrong"
    end

    test "list_runs returns runs for agent", %{scope: scope} do
      agent = agent_fixture(scope)
      _run = agent_run_fixture(agent)
      assert [_] = Agents.list_runs(agent)
    end

    test "get_run_with_steps returns run with steps", %{scope: scope} do
      agent = agent_fixture(scope)
      run = agent_run_fixture(agent)
      _step = agent_step_fixture(run, %{step_number: 1})

      {:ok, loaded} = Agents.get_run_with_steps(agent, run.id)
      assert length(loaded.steps) == 1
    end
  end

  # ── Steps ────────────────────────────────────────────────────

  describe "create_step/2" do
    test "creates a step for a run", %{scope: scope} do
      agent = agent_fixture(scope)
      run = agent_run_fixture(agent)

      assert {:ok, %AgentStep{} = step} = Agents.create_step(run, %{
        step_number: 1,
        step_type: "llm_call",
        tokens_used: 200,
        duration_ms: 1000
      })

      assert step.step_number == 1
      assert step.step_type == "llm_call"
    end
  end

  # ── Memory ───────────────────────────────────────────────────

  describe "memory" do
    test "upsert_memory creates new memory", %{scope: scope} do
      agent = agent_fixture(scope)

      assert {:ok, %AgentMemory{} = mem} = Agents.upsert_memory(agent, %{
        key: "test_key",
        value: %{"data" => "hello"},
        memory_type: "fact"
      })

      assert mem.key == "test_key"
    end

    test "upsert_memory updates existing memory", %{scope: scope} do
      agent = agent_fixture(scope)

      {:ok, _} = Agents.upsert_memory(agent, %{
        key: "test_key",
        value: %{"data" => "hello"},
        memory_type: "fact"
      })

      {:ok, updated} = Agents.upsert_memory(agent, %{
        key: "test_key",
        value: %{"data" => "updated"},
        memory_type: "fact"
      })

      assert updated.value == %{"data" => "updated"}
    end

    test "get_memory returns memory by key", %{scope: scope} do
      agent = agent_fixture(scope)
      _mem = agent_memory_fixture(agent, %{key: "my_key"})

      found = Agents.get_memory(agent, "my_key")
      assert found.key == "my_key"
    end

    test "list_memories excludes expired", %{scope: scope} do
      agent = agent_fixture(scope)

      _active = agent_memory_fixture(agent, %{key: "active"})
      _expired = agent_memory_fixture(agent, %{
        key: "expired",
        expires_at: DateTime.add(DateTime.utc_now(), -3600)
      })

      memories = Agents.list_memories(agent)
      assert length(memories) == 1
      assert hd(memories).key == "active"
    end

    test "delete_memory removes a memory", %{scope: scope} do
      agent = agent_fixture(scope)
      _mem = agent_memory_fixture(agent, %{key: "to_delete"})

      assert {:ok, _} = Agents.delete_memory(agent, "to_delete")
      assert Agents.get_memory(agent, "to_delete") == nil
    end

    test "delete_all_memories clears all", %{scope: scope} do
      agent = agent_fixture(scope)
      _m1 = agent_memory_fixture(agent, %{key: "k1"})
      _m2 = agent_memory_fixture(agent, %{key: "k2"})

      Agents.delete_all_memories(agent)
      assert Agents.list_memories(agent) == []
    end
  end

  # ── Schedules ──────────────────────────────────────────────

  describe "schedules" do
    test "create_schedule with valid cron", %{scope: scope} do
      agent = agent_fixture(scope)

      assert {:ok, %AgentSchedule{} = schedule} =
        Agents.create_schedule(agent, %{"cron" => "*/5 * * * *", "message" => "hello"})

      assert schedule.cron == "*/5 * * * *"
      assert schedule.message == "hello"
      assert schedule.enabled == true
    end

    test "create_schedule rejects invalid cron", %{scope: scope} do
      agent = agent_fixture(scope)

      assert {:error, changeset} =
        Agents.create_schedule(agent, %{"cron" => "not a cron", "message" => "hello"})

      assert %{cron: _} = errors_on(changeset)
    end

    test "list_schedules returns schedules for agent", %{scope: scope} do
      agent = agent_fixture(scope)
      _s = schedule_fixture(agent)
      assert [_] = Agents.list_schedules(agent)
    end

    test "get_schedule returns schedule by id", %{scope: scope} do
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)
      assert {:ok, found} = Agents.get_schedule(agent, schedule.id)
      assert found.id == schedule.id
    end

    test "get_schedule returns error for wrong agent", %{scope: scope} do
      agent1 = agent_fixture(scope)
      agent2 = agent_fixture(scope)
      schedule = schedule_fixture(agent1)
      assert {:error, :not_found} = Agents.get_schedule(agent2, schedule.id)
    end

    test "update_schedule changes fields", %{scope: scope} do
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)

      assert {:ok, updated} = Agents.update_schedule(schedule, %{"cron" => "0 * * * *", "enabled" => false})
      assert updated.cron == "0 * * * *"
      assert updated.enabled == false
    end

    test "delete_schedule removes schedule", %{scope: scope} do
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)

      assert {:ok, _} = Agents.delete_schedule(schedule)
      assert {:error, :not_found} = Agents.get_schedule(agent, schedule.id)
    end

    test "update_schedule_last_run sets timestamp", %{scope: scope} do
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)
      assert schedule.last_run_at == nil

      assert {:ok, updated} = Agents.update_schedule_last_run(schedule)
      assert updated.last_run_at != nil
    end

    test "create_schedule rejects message exceeding max length", %{scope: scope} do
      agent = agent_fixture(scope)
      long_message = String.duplicate("a", 1001)

      assert {:error, changeset} =
        Agents.create_schedule(agent, %{"cron" => "*/5 * * * *", "message" => long_message})

      assert %{message: ["should be at most 1000 character(s)"]} = errors_on(changeset)
    end

    test "create_schedule rejects cron exceeding max length", %{scope: scope} do
      agent = agent_fixture(scope)
      long_cron = String.duplicate("* ", 128)

      assert {:error, changeset} =
        Agents.create_schedule(agent, %{"cron" => long_cron})

      assert %{cron: _} = errors_on(changeset)
    end

    test "create_schedule accepts message at max length", %{scope: scope} do
      agent = agent_fixture(scope)
      max_message = String.duplicate("a", 1000)

      assert {:ok, schedule} =
        Agents.create_schedule(agent, %{"cron" => "*/5 * * * *", "message" => max_message})

      assert schedule.message == max_message
    end
  end
end
