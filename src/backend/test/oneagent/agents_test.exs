defmodule OneAgent.AgentsTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Agents
  alias OneAgent.Agents.{Agent, AgentBucket, AgentStep, AgentMemory, AgentSchedule, AgentGoal}

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

    test "fails with description exceeding max length", %{scope: scope} do
      attrs = valid_agent_attributes(%{"description" => String.duplicate("a", 10_001)})
      assert {:error, changeset} = Agents.create_agent(scope, attrs)
      assert %{description: ["should be at most 10000 character(s)"]} = errors_on(changeset)
    end

    test "fails with model_id exceeding max length", %{scope: scope} do
      attrs = valid_agent_attributes(%{"model_id" => String.duplicate("a", 256)})
      assert {:error, changeset} = Agents.create_agent(scope, attrs)
      assert %{model_id: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "accepts description at max length", %{scope: scope} do
      attrs = valid_agent_attributes(%{"description" => String.duplicate("a", 10_000)})
      assert {:ok, %Agent{}} = Agents.create_agent(scope, attrs)
    end

    test "accepts valid model_config with max_tokens", %{scope: scope} do
      attrs = valid_agent_attributes(%{"model_config" => %{"max_tokens" => 4096}})
      assert {:ok, %Agent{} = agent} = Agents.create_agent(scope, attrs)
      assert agent.model_config == %{"max_tokens" => 4096}
    end

    test "accepts empty model_config", %{scope: scope} do
      attrs = valid_agent_attributes(%{"model_config" => %{}})
      assert {:ok, %Agent{}} = Agents.create_agent(scope, attrs)
    end

    test "rejects model_config with unknown keys", %{scope: scope} do
      attrs = valid_agent_attributes(%{"model_config" => %{"max_tokens" => 4096, "evil" => "payload", "temperature" => 0.5}})
      assert {:error, changeset} = Agents.create_agent(scope, attrs)
      assert %{model_config: [msg]} = errors_on(changeset)
      assert msg =~ "unknown keys"
      assert msg =~ "evil"
      assert msg =~ "temperature"
    end

    test "rejects model_config with non-integer max_tokens", %{scope: scope} do
      attrs = valid_agent_attributes(%{"model_config" => %{"max_tokens" => "lots"}})
      assert {:error, changeset} = Agents.create_agent(scope, attrs)
      assert %{model_config: ["max_tokens must be an integer between 1 and 100000"]} = errors_on(changeset)
    end

    test "rejects model_config with max_tokens out of range", %{scope: scope} do
      attrs = valid_agent_attributes(%{"model_config" => %{"max_tokens" => 0}})
      assert {:error, changeset} = Agents.create_agent(scope, attrs)
      assert %{model_config: ["max_tokens must be an integer between 1 and 100000"]} = errors_on(changeset)

      attrs = valid_agent_attributes(%{"model_config" => %{"max_tokens" => 100_001}})
      assert {:error, changeset} = Agents.create_agent(scope, attrs)
      assert %{model_config: ["max_tokens must be an integer between 1 and 100000"]} = errors_on(changeset)
    end

    test "rejects model_config with arbitrary large data", %{scope: scope} do
      # Attempt to store a large arbitrary map — should be rejected due to unknown keys
      big_map = for i <- 1..100, into: %{}, do: {"key_#{i}", String.duplicate("x", 1000)}
      attrs = valid_agent_attributes(%{"model_config" => big_map})
      assert {:error, changeset} = Agents.create_agent(scope, attrs)
      assert %{model_config: [msg]} = errors_on(changeset)
      assert msg =~ "unknown keys"
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

    test "upsert_memory rejects oversized value", %{scope: scope} do
      agent = agent_fixture(scope)
      # Generate a value that exceeds the 10 KB limit
      large_value = %{"data" => String.duplicate("x", 15_000)}

      assert {:error, changeset} = Agents.upsert_memory(agent, %{
        key: "big_key",
        value: large_value,
        memory_type: "fact"
      })

      assert {"is too large" <> _, _} = changeset.errors[:value]
    end

    test "upsert_memory accepts value within size limit", %{scope: scope} do
      agent = agent_fixture(scope)
      # A value that fits within 10 KB
      value = %{"data" => String.duplicate("x", 5_000)}

      assert {:ok, %AgentMemory{}} = Agents.upsert_memory(agent, %{
        key: "ok_key",
        value: value,
        memory_type: "fact"
      })
    end

    test "delete_all_memories clears all", %{scope: scope} do
      agent = agent_fixture(scope)
      _m1 = agent_memory_fixture(agent, %{key: "k1"})
      _m2 = agent_memory_fixture(agent, %{key: "k2"})

      Agents.delete_all_memories(agent)
      assert Agents.list_memories(agent) == []
    end

    test "count_memories returns correct count", %{scope: scope} do
      agent = agent_fixture(scope)
      assert Agents.count_memories(agent) == 0

      agent_memory_fixture(agent, %{key: "k1"})
      assert Agents.count_memories(agent) == 1

      agent_memory_fixture(agent, %{key: "k2"})
      assert Agents.count_memories(agent) == 2
    end
  end

  # ── Memory Full-Text Search ───────────────────────────────

  describe "search_memories/3" do
    test "finds memories by key text", %{scope: scope} do
      agent = agent_fixture(scope)
      _m = agent_memory_fixture(agent, %{key: "user_favorite_color", value: %{"color" => "blue"}, memory_type: "preference"})

      results = Agents.search_memories(agent, "favorite color")
      assert length(results) == 1
      assert hd(results).memory.key == "user_favorite_color"
    end

    test "finds memories by value text", %{scope: scope} do
      agent = agent_fixture(scope)
      _m = agent_memory_fixture(agent, %{key: "pref1", value: %{"food" => "spaghetti carbonara"}, memory_type: "preference"})

      results = Agents.search_memories(agent, "spaghetti")
      assert length(results) == 1
      assert hd(results).memory.key == "pref1"
    end

    test "ranks key matches higher than value matches", %{scope: scope} do
      agent = agent_fixture(scope)
      _key_match = agent_memory_fixture(agent, %{key: "python_programming", value: %{"info" => "unrelated"}, memory_type: "fact"})
      _val_match = agent_memory_fixture(agent, %{key: "random_fact", value: %{"detail" => "python is a programming language"}, memory_type: "fact"})

      results = Agents.search_memories(agent, "python")
      assert length(results) == 2
      # Key match (weight A) should rank higher than value match (weight B)
      [first, second] = results
      assert first.memory.key == "python_programming"
      assert second.memory.key == "random_fact"
      assert first.rank >= second.rank
    end

    test "excludes expired memories", %{scope: scope} do
      agent = agent_fixture(scope)
      _active = agent_memory_fixture(agent, %{key: "active_memory", value: %{"data" => "searchable content"}, memory_type: "fact"})
      _expired = agent_memory_fixture(agent, %{key: "expired_memory", value: %{"data" => "searchable content"}, memory_type: "fact", expires_at: DateTime.add(DateTime.utc_now(), -3600)})

      results = Agents.search_memories(agent, "searchable")
      assert length(results) == 1
      assert hd(results).memory.key == "active_memory"
    end

    test "scopes results to the given agent", %{scope: scope} do
      agent1 = agent_fixture(scope)
      agent2 = agent_fixture(scope)
      _m1 = agent_memory_fixture(agent1, %{key: "shared_topic", value: %{"data" => "agent1 data"}, memory_type: "fact"})
      _m2 = agent_memory_fixture(agent2, %{key: "shared_topic", value: %{"data" => "agent2 data"}, memory_type: "fact"})

      results = Agents.search_memories(agent1, "shared topic")
      assert length(results) == 1
      assert hd(results).memory.value == %{"data" => "agent1 data"}
    end

    test "respects limit option", %{scope: scope} do
      agent = agent_fixture(scope)
      for i <- 1..5 do
        agent_memory_fixture(agent, %{key: "item_#{i}", value: %{"data" => "searchable item"}, memory_type: "fact"})
      end

      results = Agents.search_memories(agent, "searchable", limit: 2)
      assert length(results) == 2
    end

    test "returns empty list for no matches", %{scope: scope} do
      agent = agent_fixture(scope)
      _m = agent_memory_fixture(agent, %{key: "something", value: %{"data" => "unrelated"}, memory_type: "fact"})

      results = Agents.search_memories(agent, "xylophone")
      assert results == []
    end

    test "returns rank as a float", %{scope: scope} do
      agent = agent_fixture(scope)
      _m = agent_memory_fixture(agent, %{key: "test_memory", value: %{"data" => "hello world"}, memory_type: "fact"})

      [result] = Agents.search_memories(agent, "hello")
      assert is_float(result.rank)
      assert result.rank > 0.0
    end
  end

  # ── Messages (Chat History) ────────────────────────────────

  describe "messages" do
    test "create_message defaults source to chat", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, msg} = Agents.create_message(agent, %{role: "user", content: "hello"})
      assert msg.source == "chat"
    end

    test "create_message stores explicit source", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, msg} = Agents.create_message(agent, %{role: "user", content: "hello", source: "scheduled"})
      assert msg.source == "scheduled"
    end

    test "create_message rejects invalid source", %{scope: scope} do
      agent = agent_fixture(scope)
      {:error, changeset} = Agents.create_message(agent, %{role: "user", content: "hello", source: "invalid"})
      assert %{source: _} = errors_on(changeset)
    end

    test "list_recent_messages excludes scheduled by default", %{scope: scope} do
      agent = agent_fixture(scope)
      _chat = message_fixture(agent, %{role: "user", content: "chat msg", source: "chat"})
      _webhook = message_fixture(agent, %{role: "user", content: "webhook msg", source: "webhook"})
      _scheduled = message_fixture(agent, %{role: "user", content: "scheduled msg", source: "scheduled"})

      messages = Agents.list_recent_messages(agent)
      sources = Enum.map(messages, & &1.source)
      assert "chat" in sources
      assert "webhook" in sources
      refute "scheduled" in sources
      assert length(messages) == 2
    end

    test "list_recent_messages with exclude_sources: [] returns all", %{scope: scope} do
      agent = agent_fixture(scope)
      _chat = message_fixture(agent, %{role: "user", content: "chat msg", source: "chat"})
      _scheduled = message_fixture(agent, %{role: "user", content: "scheduled msg", source: "scheduled"})

      messages = Agents.list_recent_messages(agent, exclude_sources: [])
      assert length(messages) == 2
    end

    test "delete_all_messages clears all sources", %{scope: scope} do
      agent = agent_fixture(scope)
      _chat = message_fixture(agent, %{role: "user", content: "chat msg", source: "chat"})
      _scheduled = message_fixture(agent, %{role: "user", content: "scheduled msg", source: "scheduled"})

      Agents.delete_all_messages(agent)
      messages = Agents.list_recent_messages(agent, exclude_sources: [])
      assert messages == []
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

    test "count_schedules returns correct count", %{scope: scope} do
      agent = agent_fixture(scope)
      assert Agents.count_schedules(agent) == 0

      schedule_fixture(agent, %{"cron" => "*/5 * * * *", "message" => "one"})
      assert Agents.count_schedules(agent) == 1

      schedule_fixture(agent, %{"cron" => "*/10 * * * *", "message" => "two"})
      assert Agents.count_schedules(agent) == 2
    end
  end

  # ── Goals ─────────────────────────────────────────────────

  describe "goals CRUD" do
    test "create_goal with valid attrs", %{scope: scope} do
      agent = agent_fixture(scope)

      assert {:ok, %AgentGoal{} = goal} = Agents.create_goal(agent, %{
        title: "Find a job",
        description: "Help user find employment",
        priority: 1
      })

      assert goal.title == "Find a job"
      assert goal.status == "active"
      assert goal.priority == 1
    end

    test "create_goal fails without title", %{scope: scope} do
      agent = agent_fixture(scope)
      assert {:error, changeset} = Agents.create_goal(agent, %{description: "no title"})
      assert %{title: _} = errors_on(changeset)
    end

    test "list_goals returns goals ordered by priority desc", %{scope: scope} do
      agent = agent_fixture(scope)
      _low = goal_fixture(agent, %{title: "Low", priority: 0})
      _high = goal_fixture(agent, %{title: "High", priority: 2})

      goals = Agents.list_goals(agent)
      assert length(goals) == 2
      assert hd(goals).title == "High"
    end

    test "list_goals filters by status", %{scope: scope} do
      agent = agent_fixture(scope)
      _active = goal_fixture(agent, %{title: "Active"})
      _paused = goal_fixture(agent, %{title: "Paused", status: "paused"})

      goals = Agents.list_goals(agent, status: "active")
      assert length(goals) == 1
      assert hd(goals).title == "Active"
    end

    test "list_goals preloads steps and review_schedule", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent)
      _step = goal_step_fixture(goal, %{title: "Step 1"})

      [loaded] = Agents.list_goals(agent)
      assert length(loaded.steps) == 1
      assert hd(loaded.steps).title == "Step 1"
    end

    test "get_goal returns goal with preloaded steps", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent)
      _step = goal_step_fixture(goal, %{title: "S1"})

      assert {:ok, found} = Agents.get_goal(agent, goal.id)
      assert found.id == goal.id
      assert length(found.steps) == 1
    end

    test "get_goal returns error for wrong agent", %{scope: scope} do
      agent1 = agent_fixture(scope)
      agent2 = agent_fixture(scope)
      goal = goal_fixture(agent1)

      assert {:error, :not_found} = Agents.get_goal(agent2, goal.id)
    end

    test "update_goal changes fields", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent)

      assert {:ok, updated} = Agents.update_goal(goal, %{title: "Updated Title", priority: 5})
      assert updated.title == "Updated Title"
      assert updated.priority == 5
    end

    test "complete_goal cascades to steps and disables schedules", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent)
      _step1 = goal_step_fixture(goal, %{title: "Pending step"})
      _step2 = goal_step_fixture(goal, %{title: "In progress step", status: "in_progress"})

      # Create a review schedule and link it
      review_schedule = schedule_fixture(agent, %{"cron" => "0 * * * *", "message" => "Review"})
      {:ok, goal} = Agents.update_goal(goal, %{review_schedule_id: review_schedule.id})

      assert {:ok, completed} = Agents.complete_goal(goal)
      assert completed.status == "completed"
      assert completed.completed_at != nil

      # Steps should be completed
      {:ok, reloaded} = Agents.get_goal(agent, goal.id)
      assert Enum.all?(reloaded.steps, &(&1.status == "completed"))

      # Review schedule should be disabled
      {:ok, sched} = Agents.get_schedule(agent, review_schedule.id)
      assert sched.enabled == false
    end

    test "abandon_goal marks steps as skipped and disables schedules", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent)
      _step = goal_step_fixture(goal, %{title: "Pending"})

      review_schedule = schedule_fixture(agent, %{"cron" => "0 * * * *", "message" => "Review"})
      {:ok, goal} = Agents.update_goal(goal, %{review_schedule_id: review_schedule.id})

      assert {:ok, abandoned} = Agents.abandon_goal(goal)
      assert abandoned.status == "abandoned"

      {:ok, reloaded} = Agents.get_goal(agent, goal.id)
      assert Enum.all?(reloaded.steps, &(&1.status == "skipped"))

      {:ok, sched} = Agents.get_schedule(agent, review_schedule.id)
      assert sched.enabled == false
    end

    test "delete_goal removes schedules and cascades", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent)

      # Create step with linked schedule
      step_schedule = schedule_fixture(agent, %{"cron" => "0 9 * * *", "message" => "Step work"})
      {:ok, _step} = Agents.create_goal_step(goal, %{title: "Scheduled step", schedule_id: step_schedule.id})

      # Create review schedule
      review_schedule = schedule_fixture(agent, %{"cron" => "0 * * * *", "message" => "Review"})
      {:ok, goal} = Agents.update_goal(goal, %{review_schedule_id: review_schedule.id})

      assert {:ok, _} = Agents.delete_goal(goal)

      # Goal should be gone
      assert {:error, :not_found} = Agents.get_goal(agent, goal.id)

      # Schedules should be deleted
      assert {:error, :not_found} = Agents.get_schedule(agent, step_schedule.id)
      assert {:error, :not_found} = Agents.get_schedule(agent, review_schedule.id)
    end

    test "count_goals returns count filtered by status", %{scope: scope} do
      agent = agent_fixture(scope)
      assert Agents.count_goals(agent, "active") == 0

      _g1 = goal_fixture(agent, %{title: "Active 1"})
      _g2 = goal_fixture(agent, %{title: "Active 2"})
      _g3 = goal_fixture(agent, %{title: "Paused", status: "paused"})

      assert Agents.count_goals(agent, "active") == 2
      assert Agents.count_goals(agent, "paused") == 1
      assert Agents.count_goals(agent, "completed") == 0
    end
  end

  # ── Goal Steps ────────────────────────────────────────────

  describe "goal steps" do
    test "create_goal_step auto-assigns position", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent)

      {:ok, s1} = Agents.create_goal_step(goal, %{title: "First"})
      {:ok, s2} = Agents.create_goal_step(goal, %{title: "Second"})

      assert s1.position == 1
      assert s2.position == 2
    end

    test "update_goal_step changes fields", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent)
      step = goal_step_fixture(goal)

      assert {:ok, updated} = Agents.update_goal_step(step, %{status: "completed", result_notes: "Done!"})
      assert updated.status == "completed"
      assert updated.result_notes == "Done!"
    end

    test "delete_goal_step cleans up linked schedule", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent)
      sched = schedule_fixture(agent, %{"cron" => "0 9 * * *", "message" => "Work"})

      {:ok, step} = Agents.create_goal_step(goal, %{title: "Scheduled", schedule_id: sched.id})

      assert {:ok, _} = Agents.delete_goal_step(step)
      assert {:error, :not_found} = Agents.get_schedule(agent, sched.id)
    end

    test "get_goal_step scoped to goal", %{scope: scope} do
      agent = agent_fixture(scope)
      goal1 = goal_fixture(agent)
      goal2 = goal_fixture(agent)
      step = goal_step_fixture(goal1)

      assert {:ok, _} = Agents.get_goal_step(goal1, step.id)
      assert {:error, :not_found} = Agents.get_goal_step(goal2, step.id)
    end

    test "get_step_by_schedule finds linked step", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent)
      sched = schedule_fixture(agent, %{"cron" => "0 9 * * *"})

      {:ok, step} = Agents.create_goal_step(goal, %{title: "Linked", schedule_id: sched.id})

      found = Agents.get_step_by_schedule(sched.id)
      assert found.id == step.id
      assert found.goal.id == goal.id
    end

    test "get_step_by_schedule returns nil for completed steps", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent)
      sched = schedule_fixture(agent, %{"cron" => "0 9 * * *"})

      {:ok, step} = Agents.create_goal_step(goal, %{title: "Done", schedule_id: sched.id})
      {:ok, _} = Agents.update_goal_step(step, %{status: "completed"})

      assert Agents.get_step_by_schedule(sched.id) == nil
    end

    test "get_goal_by_review_schedule finds active goal", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent)
      sched = schedule_fixture(agent, %{"cron" => "0 * * * *"})
      {:ok, goal} = Agents.update_goal(goal, %{review_schedule_id: sched.id})

      found = Agents.get_goal_by_review_schedule(sched.id)
      assert found.id == goal.id
    end

    test "get_goal_by_review_schedule returns nil for non-active goal", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent, %{status: "completed"})
      sched = schedule_fixture(agent, %{"cron" => "0 * * * *"})
      {:ok, _} = Agents.update_goal(goal, %{review_schedule_id: sched.id})

      assert Agents.get_goal_by_review_schedule(sched.id) == nil
    end

    test "create_step_with_schedule creates step and schedule in transaction", %{scope: scope} do
      agent = agent_fixture(scope)
      goal = goal_fixture(agent)

      step_attrs = %{title: "Daily check"}
      sched_attrs = %{"cron" => "0 9 * * *", "message" => "Run daily check"}

      assert {:ok, step} = Agents.create_step_with_schedule(goal, step_attrs, sched_attrs)
      assert step.title == "Daily check"
      assert step.schedule_id != nil

      # Verify schedule was created
      {:ok, sched} = Agents.get_schedule(agent, step.schedule_id)
      assert sched.cron == "0 9 * * *"
    end
  end
end
