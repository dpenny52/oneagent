defmodule OneAgentWeb.AgentControllerTest do
  use OneAgentWeb.ConnCase, async: true

  import OneAgent.AgentsFixtures
  import OneAgent.CredentialsFixtures, except: [scope_fixture: 0]

  setup :register_and_log_in_user

  describe "GET /api/agents" do
    test "lists agents for authenticated user", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      _agent = agent_fixture(scope)

      conn = get(conn, "/api/agents")
      assert %{"data" => [%{"id" => _}]} = json_response(conn, 200)
    end

    test "returns empty list when no agents", %{conn: conn} do
      conn = get(conn, "/api/agents")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 401 without auth" do
      conn = build_conn() |> put_req_header("accept", "application/json")
      conn = get(conn, "/api/agents")
      assert json_response(conn, 401)
    end
  end

  describe "POST /api/agents" do
    test "creates an agent", %{conn: conn} do
      attrs = valid_agent_attributes()
      conn = post(conn, "/api/agents", %{"agent" => attrs})

      assert %{"data" => %{"id" => id, "name" => name, "has_llm_config" => false}} = json_response(conn, 201)
      assert name == attrs["name"]
      assert id != nil
    end

    test "returns errors for invalid attrs", %{conn: conn} do
      conn = post(conn, "/api/agents", %{"agent" => %{}})
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "rejects another user's llm_config_id", %{conn: conn} do
      other_scope = scope_fixture()
      other_config = llm_config_fixture(other_scope)

      attrs = valid_agent_attributes(%{"llm_config_id" => other_config.id})
      conn = post(conn, "/api/agents", %{"agent" => attrs})

      assert %{"error" => _} = json_response(conn, 422)
    end
  end

  describe "GET /api/agents/:id" do
    test "shows an agent", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      conn = get(conn, "/api/agents/#{agent.id}")
      assert %{"data" => %{"id" => id}} = json_response(conn, 200)
      assert id == agent.id
    end

    test "returns 404 for non-existent agent", %{conn: conn} do
      conn = get(conn, "/api/agents/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/agents/:id" do
    test "updates an agent", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      conn = put(conn, "/api/agents/#{agent.id}", %{"agent" => %{"name" => "Updated"}})
      assert %{"data" => %{"name" => "Updated"}} = json_response(conn, 200)
    end

    test "rejects another user's llm_config_id", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      other_scope = scope_fixture()
      other_config = llm_config_fixture(other_scope)

      conn = put(conn, "/api/agents/#{agent.id}", %{
        "agent" => %{"llm_config_id" => other_config.id}
      })

      assert %{"error" => _} = json_response(conn, 422)
    end
  end

  describe "DELETE /api/agents/:id" do
    test "deletes an agent", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      conn = delete(conn, "/api/agents/#{agent.id}")
      assert response(conn, 204)
    end
  end

  describe "GET /api/agents/:agent_id/buckets" do
    test "lists active buckets", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_with_buckets_fixture(scope, ["web_access", "email"])

      conn = get(conn, "/api/agents/#{agent.id}/buckets")
      assert %{"data" => buckets} = json_response(conn, 200)
      assert length(buckets) == 2
    end
  end

  describe "PUT /api/agents/:agent_id/buckets" do
    test "replaces buckets", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_with_buckets_fixture(scope, ["web_access"])

      conn = put(conn, "/api/agents/#{agent.id}/buckets", %{
        "buckets" => [%{"bucket" => "email"}, %{"bucket" => "data_write"}]
      })

      assert %{"data" => buckets} = json_response(conn, 200)
      assert length(buckets) == 2
      bucket_names = Enum.map(buckets, & &1["bucket"])
      assert "email" in bucket_names
      assert "data_write" in bucket_names
    end

    test "ignores unknown keys in bucket configs without crashing", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      conn = put(conn, "/api/agents/#{agent.id}/buckets", %{
        "buckets" => [%{"bucket" => "email", "unknown_key" => "evil", "__proto__" => "bad"}]
      })

      assert %{"data" => buckets} = json_response(conn, 200)
      assert length(buckets) == 1
    end

    test "rejects another user's credential_id", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      # Create a credential owned by a different user
      other_scope = scope_fixture()
      other_cred = credential_fixture(other_scope)

      conn = put(conn, "/api/agents/#{agent.id}/buckets", %{
        "buckets" => [%{"bucket" => "web_access", "credential_id" => other_cred.id}]
      })

      assert %{"error" => _} = json_response(conn, 422)
    end
  end

  describe "GET /api/agents/:agent_id/runs" do
    test "lists runs for an agent", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)
      _run = agent_run_fixture(agent)

      conn = get(conn, "/api/agents/#{agent.id}/runs")
      assert %{"data" => [%{"id" => _}]} = json_response(conn, 200)
    end
  end

  describe "GET /api/agents/:agent_id/runs/:id" do
    test "shows a run with steps", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)
      run = agent_run_fixture(agent)
      _step = agent_step_fixture(run)

      conn = get(conn, "/api/agents/#{agent.id}/runs/#{run.id}")
      assert %{"data" => %{"id" => _, "steps" => [_]}} = json_response(conn, 200)
    end
  end

  describe "GET /api/agents/:agent_id/memory" do
    test "lists memories", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)
      _mem = agent_memory_fixture(agent)

      conn = get(conn, "/api/agents/#{agent.id}/memory")
      assert %{"data" => [%{"key" => _}]} = json_response(conn, 200)
    end
  end

  describe "DELETE /api/agents/:agent_id/memory" do
    test "clears all memories", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)
      _mem = agent_memory_fixture(agent)

      conn = delete(conn, "/api/agents/#{agent.id}/memory")
      assert response(conn, 204)
    end
  end

  # ── Schedules ──────────────────────────────────────────────

  describe "GET /api/agents/:agent_id/schedules" do
    test "lists schedules for agent", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)
      _schedule = schedule_fixture(agent)

      conn = get(conn, "/api/agents/#{agent.id}/schedules")
      assert %{"data" => [%{"id" => _, "cron" => "*/5 * * * *"}]} = json_response(conn, 200)
    end
  end

  describe "POST /api/agents/:agent_id/schedules" do
    test "creates a schedule", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      conn = post(conn, "/api/agents/#{agent.id}/schedules", %{
        "schedule" => %{"cron" => "0 * * * *", "message" => "hourly check"}
      })

      assert %{"data" => %{"id" => _, "cron" => "0 * * * *", "message" => "hourly check", "enabled" => true}} =
        json_response(conn, 201)
    end

    test "rejects invalid cron", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      conn = post(conn, "/api/agents/#{agent.id}/schedules", %{
        "schedule" => %{"cron" => "bad cron"}
      })

      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "rejects schedule for another user's agent", %{conn: conn} do
      other_scope = scope_fixture()
      other_agent = agent_fixture(other_scope)

      conn = post(conn, "/api/agents/#{other_agent.id}/schedules", %{
        "schedule" => %{"cron" => "0 * * * *"}
      })

      assert json_response(conn, 404)
    end

    test "rejects schedule with oversized message", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      conn = post(conn, "/api/agents/#{agent.id}/schedules", %{
        "schedule" => %{"cron" => "0 * * * *", "message" => String.duplicate("a", 1001)}
      })

      assert %{"errors" => %{"message" => _}} = json_response(conn, 422)
    end
  end

  describe "PUT /api/agents/:agent_id/schedules/:id" do
    test "updates a schedule", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)

      conn = put(conn, "/api/agents/#{agent.id}/schedules/#{schedule.id}", %{
        "schedule" => %{"cron" => "0 9 * * *", "enabled" => false}
      })

      assert %{"data" => %{"cron" => "0 9 * * *", "enabled" => false}} = json_response(conn, 200)
    end
  end

  describe "DELETE /api/agents/:agent_id/schedules/:id" do
    test "deletes a schedule", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)

      conn = delete(conn, "/api/agents/#{agent.id}/schedules/#{schedule.id}")
      assert response(conn, 204)
    end
  end

  # ── Messages ─────────────────────────────────────────────────

  describe "GET /api/agents/:agent_id/messages" do
    test "excludes scheduled user messages but includes scheduled assistant messages", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)
      _chat = message_fixture(agent, %{role: "user", content: "chat msg", source: "chat"})
      _scheduled_user = message_fixture(agent, %{role: "user", content: "Execute your scheduled task", source: "scheduled"})
      _scheduled_assistant = message_fixture(agent, %{role: "assistant", content: "scheduled response", source: "scheduled"})

      conn = get(conn, "/api/agents/#{agent.id}/messages")
      assert %{"data" => messages} = json_response(conn, 200)
      assert length(messages) == 2
      contents = Enum.map(messages, & &1["content"])
      assert "chat msg" in contents
      assert "scheduled response" in contents
      refute "Execute your scheduled task" in contents
    end

    test "includes source field in response", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)
      _msg = message_fixture(agent, %{role: "user", content: "hello", source: "webhook"})

      conn = get(conn, "/api/agents/#{agent.id}/messages")
      assert %{"data" => [%{"source" => "webhook"}]} = json_response(conn, 200)
    end
  end

  # ── Goals ──────────────────────────────────────────────────

  describe "GET /api/agents/:agent_id/goals" do
    test "lists goals with steps for agent", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)
      goal = goal_fixture(agent, %{title: "My Goal", description: "Goal desc"})
      _step = goal_step_fixture(goal, %{title: "Step 1", position: 1})

      conn = get(conn, "/api/agents/#{agent.id}/goals")

      assert %{"data" => [%{"id" => _, "title" => "My Goal", "description" => "Goal desc", "steps" => [%{"title" => "Step 1"}]}]} =
        json_response(conn, 200)
    end

    test "returns empty list when no goals", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      conn = get(conn, "/api/agents/#{agent.id}/goals")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "rejects request for another user's agent", %{conn: conn} do
      other_scope = scope_fixture()
      other_agent = agent_fixture(other_scope)

      conn = get(conn, "/api/agents/#{other_agent.id}/goals")
      assert json_response(conn, 404)
    end
  end

  # ── Invoke (input validation) ───────────────────────────────

  describe "POST /api/agents/:agent_id/invoke" do
    test "rejects null message", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      conn = post(conn, "/api/agents/#{agent.id}/invoke", %{"message" => nil})
      assert %{"error" => "Message must be a non-empty string"} = json_response(conn, 422)
    end

    test "rejects non-string message", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      conn = post(conn, "/api/agents/#{agent.id}/invoke", %{"message" => 123})
      assert %{"error" => "Message must be a non-empty string"} = json_response(conn, 422)
    end

    test "rejects empty string message", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      conn = post(conn, "/api/agents/#{agent.id}/invoke", %{"message" => ""})
      assert %{"error" => "Message must not be blank"} = json_response(conn, 422)
    end

    test "rejects whitespace-only message", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      conn = post(conn, "/api/agents/#{agent.id}/invoke", %{"message" => "   \n\t  "})
      assert %{"error" => "Message must not be blank"} = json_response(conn, 422)
    end

    test "rejects oversized message", %{conn: conn, user: user} do
      scope = OneAgent.Accounts.Scope.for_user(user)
      agent = agent_fixture(scope)

      conn = post(conn, "/api/agents/#{agent.id}/invoke", %{"message" => String.duplicate("a", 32_001)})
      assert %{"error" => "Message exceeds maximum length of 32000 characters"} = json_response(conn, 422)
    end

    test "returns 404 for non-existent agent", %{conn: conn} do
      conn = post(conn, "/api/agents/#{Ecto.UUID.generate()}/invoke", %{"message" => "hello"})
      assert json_response(conn, 404)
    end
  end
end
