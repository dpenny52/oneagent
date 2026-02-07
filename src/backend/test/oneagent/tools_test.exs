defmodule OneAgent.ToolsTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools
  alias OneAgent.Agents

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    %{scope: scope}
  end

  describe "all_tools/0" do
    test "returns all registered tools" do
      tools = Tools.all_tools()
      assert length(tools) == 8

      ids = Enum.map(tools, & &1.id())
      assert "http_request" in ids
      assert "read_webpage" in ids
      assert "send_email" in ids
      assert "check_email" in ids
      assert "store_memory" in ids
      assert "recall_memory" in ids
      assert "list_schedules" in ids
      assert "manage_schedule" in ids
    end
  end

  describe "get_tool/1" do
    test "finds tool by id" do
      assert Tools.get_tool("http_request") == OneAgent.Tools.HttpRequest
      assert Tools.get_tool("store_memory") == OneAgent.Tools.StoreMemory
      assert Tools.get_tool("list_schedules") == OneAgent.Tools.ListSchedules
      assert Tools.get_tool("manage_schedule") == OneAgent.Tools.ManageSchedule
    end

    test "returns nil for unknown tool" do
      assert Tools.get_tool("nonexistent") == nil
    end
  end

  describe "tool_definitions_for_agent/1" do
    test "includes memory and schedule tools regardless of buckets", %{scope: scope} do
      agent = agent_fixture(scope)
      # Agent has no buckets granted

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

      assert "store_memory" in names
      assert "recall_memory" in names
      assert "list_schedules" in names
      assert "manage_schedule" in names
      # http_request included (dynamic bucket, nil static)
      assert "http_request" in names
    end

    test "includes bucket-gated tools when bucket is granted", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "web_access"})
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "email"})

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

      assert "read_webpage" in names
      assert "send_email" in names
    end

    test "excludes tools when bucket not granted", %{scope: scope} do
      agent = agent_fixture(scope)
      # Only grant web_access, not email
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "web_access"})

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

      assert "read_webpage" in names
      refute "send_email" in names
    end

    test "includes check_email when gmail bucket is granted", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "gmail"})

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

      assert "check_email" in names
    end

    test "excludes check_email when gmail bucket not granted", %{scope: scope} do
      agent = agent_fixture(scope)

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

      refute "check_email" in names
    end
  end

  describe "execute_tool/3 permission checking" do
    test "rejects tool when bucket not approved", %{scope: scope} do
      agent = agent_fixture(scope)
      # No email bucket
      context = %{agent: agent}

      assert {:error, msg} = Tools.execute_tool("send_email", %{}, context)
      assert msg =~ "Permission denied"
      assert msg =~ "email"
    end

    test "rejects check_email when gmail bucket not approved", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      assert {:error, msg} = Tools.execute_tool("check_email", %{"action" => "list"}, context)
      assert msg =~ "Permission denied"
      assert msg =~ "gmail"
    end

    test "rejects http_request POST when data_write not approved", %{scope: scope} do
      agent = agent_fixture(scope)
      # Only grant web_access, not data_write
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "web_access"})
      context = %{agent: agent}

      input = %{"method" => "POST", "url" => "https://example.com"}
      assert {:error, msg} = Tools.execute_tool("http_request", input, context)
      assert msg =~ "data_write"
    end

    test "allows memory tools without any buckets", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil}

      assert {:ok, result} = Tools.execute_tool("recall_memory", %{}, context)
      assert result["count"] == 0
    end

    test "allows schedule tools without any buckets", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil}

      assert {:ok, result} = Tools.execute_tool("list_schedules", %{}, context)
      assert result["count"] == 0
    end

    test "returns error for unknown tool", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      assert {:error, "Unknown tool: nonexistent"} =
        Tools.execute_tool("nonexistent", %{}, context)
    end
  end

  describe "http_request method validation" do
    test "returns error for invalid HTTP method instead of crashing", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "web_access"})
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "data_write"})
      context = %{agent: agent}

      assert {:error, msg} =
               Tools.execute_tool("http_request", %{"method" => "FOOBAR", "url" => "https://example.com"}, context)

      assert msg =~ "Invalid HTTP method"
      assert msg =~ "FOOBAR"
    end

    test "returns error for nil HTTP method", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "data_write"})
      context = %{agent: agent}

      assert {:error, msg} =
               Tools.execute_tool("http_request", %{"method" => nil, "url" => "https://example.com"}, context)

      assert msg =~ "Invalid HTTP method"
    end
  end

  describe "http_request SSRF protection" do
    test "blocks requests to private IPs", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "web_access"})
      context = %{agent: agent}

      assert {:error, msg} =
               Tools.execute_tool("http_request", %{"method" => "GET", "url" => "http://169.254.169.254/latest/meta-data/"}, context)

      assert msg =~ "private"
    end

    test "blocks requests to localhost", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "web_access"})
      context = %{agent: agent}

      assert {:error, msg} =
               Tools.execute_tool("http_request", %{"method" => "GET", "url" => "http://localhost/admin"}, context)

      assert msg =~ "not allowed"
    end

    test "blocks non-http schemes", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "web_access"})
      context = %{agent: agent}

      assert {:error, msg} =
               Tools.execute_tool("http_request", %{"method" => "GET", "url" => "file:///etc/passwd"}, context)

      assert msg =~ "http or https"
    end
  end

  describe "read_webpage SSRF protection" do
    test "blocks requests to private IPs", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "web_access"})
      context = %{agent: agent}

      assert {:error, msg} =
               Tools.execute_tool("read_webpage", %{"url" => "http://10.0.0.1/internal"}, context)

      assert msg =~ "private"
    end

    test "blocks requests to metadata endpoints", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "web_access"})
      context = %{agent: agent}

      assert {:error, msg} =
               Tools.execute_tool("read_webpage", %{"url" => "http://metadata.google.internal/computeMetadata/v1/"}, context)

      assert msg =~ "not allowed"
    end

    test "blocks non-http schemes", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "web_access"})
      context = %{agent: agent}

      assert {:error, msg} =
               Tools.execute_tool("read_webpage", %{"url" => "ftp://internal.corp/data"}, context)

      assert msg =~ "http or https"
    end
  end

  describe "send_email recipient validation" do
    setup %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "email"})
      %{agent: agent, context: %{agent: agent}}
    end

    test "rejects missing recipient", %{context: context} do
      assert {:error, msg} =
               Tools.execute_tool("send_email", %{"subject" => "Hi", "body" => "Hello"}, context)

      assert msg =~ "Missing required parameter: to"
    end

    test "rejects empty recipient", %{context: context} do
      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "", "subject" => "Hi", "body" => "Hello"},
                 context
               )

      assert msg =~ "Missing required parameter: to"
    end

    test "rejects email with spaces (header injection)", %{context: context} do
      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "user @example.com", "subject" => "Hi", "body" => "Hello"},
                 context
               )

      assert msg =~ "Invalid recipient email"
    end

    test "rejects email with newlines (header injection)", %{context: context} do
      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "user@example.com\nBcc: victim@evil.com", "subject" => "Hi", "body" => "Hello"},
                 context
               )

      assert msg =~ "Invalid recipient email"
    end

    test "rejects comma-separated recipients", %{context: context} do
      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "a@b.com,c@d.com", "subject" => "Hi", "body" => "Hello"},
                 context
               )

      assert msg =~ "Invalid recipient email"
    end

    test "rejects semicolon-separated recipients", %{context: context} do
      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "a@b.com;c@d.com", "subject" => "Hi", "body" => "Hello"},
                 context
               )

      assert msg =~ "Invalid recipient email"
    end

    test "rejects email without @", %{context: context} do
      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "not-an-email", "subject" => "Hi", "body" => "Hello"},
                 context
               )

      assert msg =~ "Invalid recipient email"
    end

    test "rejects email exceeding 254 characters", %{context: context} do
      long_email = String.duplicate("a", 250) <> "@b.com"

      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => long_email, "subject" => "Hi", "body" => "Hello"},
                 context
               )

      assert msg =~ "too long"
    end
  end

  describe "send_email subject and body validation" do
    setup %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "email"})
      %{agent: agent, context: %{agent: agent}}
    end

    test "rejects missing subject", %{context: context} do
      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "user@example.com", "body" => "Hello"},
                 context
               )

      assert msg =~ "Missing required parameter: subject"
    end

    test "rejects empty subject", %{context: context} do
      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "user@example.com", "subject" => "", "body" => "Hello"},
                 context
               )

      assert msg =~ "Missing required parameter: subject"
    end

    test "rejects whitespace-only subject", %{context: context} do
      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "user@example.com", "subject" => "   ", "body" => "Hello"},
                 context
               )

      assert msg =~ "Missing required parameter: subject"
    end

    test "rejects subject exceeding 998 characters", %{context: context} do
      long_subject = String.duplicate("a", 999)

      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "user@example.com", "subject" => long_subject, "body" => "Hello"},
                 context
               )

      assert msg =~ "Subject too long"
    end

    test "rejects missing body", %{context: context} do
      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "user@example.com", "subject" => "Hi"},
                 context
               )

      assert msg =~ "Missing required parameter: body"
    end

    test "rejects empty body", %{context: context} do
      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "user@example.com", "subject" => "Hi", "body" => ""},
                 context
               )

      assert msg =~ "Missing required parameter: body"
    end

    test "rejects whitespace-only body", %{context: context} do
      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "user@example.com", "subject" => "Hi", "body" => "  \n  "},
                 context
               )

      assert msg =~ "Missing required parameter: body"
    end

    test "rejects body exceeding 100,000 characters", %{context: context} do
      long_body = String.duplicate("a", 100_001)

      assert {:error, msg} =
               Tools.execute_tool(
                 "send_email",
                 %{"to" => "user@example.com", "subject" => "Hi", "body" => long_body},
                 context
               )

      assert msg =~ "Body too long"
    end
  end

  describe "store_memory and recall_memory tools" do
    test "store and recall round-trip", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil}

      # Store
      assert {:ok, %{"stored" => true}} =
        Tools.execute_tool("store_memory", %{
          "key" => "test_key",
          "value" => %{"answer" => 42},
          "memory_type" => "fact"
        }, context)

      # Recall by key
      assert {:ok, result} =
        Tools.execute_tool("recall_memory", %{"key" => "test_key"}, context)

      assert result["found"] == true
      assert result["value"] == %{"answer" => 42}
    end

    test "recall lists all memories when no key given", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil}

      Tools.execute_tool("store_memory", %{
        "key" => "k1", "value" => %{"a" => 1}, "memory_type" => "fact"
      }, context)

      Tools.execute_tool("store_memory", %{
        "key" => "k2", "value" => %{"b" => 2}, "memory_type" => "preference"
      }, context)

      assert {:ok, result} = Tools.execute_tool("recall_memory", %{}, context)
      assert result["count"] == 2
    end

    test "recall treats empty string key as list-all", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil}

      Tools.execute_tool("store_memory", %{
        "key" => "k1", "value" => %{"a" => 1}, "memory_type" => "fact"
      }, context)

      assert {:ok, result} = Tools.execute_tool("recall_memory", %{"key" => ""}, context)
      assert result["count"] == 1
      assert is_list(result["memories"])
    end

    test "recall treats whitespace-only key as list-all", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil}

      Tools.execute_tool("store_memory", %{
        "key" => "k1", "value" => %{"x" => true}, "memory_type" => "fact"
      }, context)

      assert {:ok, result} = Tools.execute_tool("recall_memory", %{"key" => "  \t  "}, context)
      assert result["count"] == 1
      assert is_list(result["memories"])
    end

    test "recall trims whitespace from key before lookup", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil}

      Tools.execute_tool("store_memory", %{
        "key" => "test_key", "value" => %{"v" => 1}, "memory_type" => "fact"
      }, context)

      assert {:ok, result} = Tools.execute_tool("recall_memory", %{"key" => "  test_key  "}, context)
      assert result["found"] == true
      assert result["key"] == "test_key"
    end
  end

  describe "list_schedules tool" do
    test "returns empty list when no schedules", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      assert {:ok, result} = Tools.execute_tool("list_schedules", %{}, context)
      assert result["schedules"] == []
      assert result["count"] == 0
    end

    test "returns all schedules", %{scope: scope} do
      agent = agent_fixture(scope)
      _s1 = schedule_fixture(agent, %{"cron" => "*/5 * * * *", "message" => "Check updates"})
      _s2 = schedule_fixture(agent, %{"cron" => "0 9 * * 1-5", "message" => "Morning brief", "enabled" => false})
      context = %{agent: agent}

      assert {:ok, result} = Tools.execute_tool("list_schedules", %{}, context)
      assert result["count"] == 2

      crons = Enum.map(result["schedules"], & &1["cron"])
      assert "*/5 * * * *" in crons
      assert "0 9 * * 1-5" in crons
    end

    test "filters to enabled_only", %{scope: scope} do
      agent = agent_fixture(scope)
      _s1 = schedule_fixture(agent, %{"cron" => "*/5 * * * *", "enabled" => true})
      _s2 = schedule_fixture(agent, %{"cron" => "0 9 * * 1-5", "enabled" => false})
      context = %{agent: agent}

      assert {:ok, result} = Tools.execute_tool("list_schedules", %{"enabled_only" => true}, context)
      assert result["count"] == 1
      assert hd(result["schedules"])["cron"] == "*/5 * * * *"
    end

    test "includes schedule fields", %{scope: scope} do
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent, %{"cron" => "0 * * * *", "message" => "Hourly"})
      context = %{agent: agent}

      assert {:ok, result} = Tools.execute_tool("list_schedules", %{}, context)
      [item] = result["schedules"]
      assert item["id"] == schedule.id
      assert item["cron"] == "0 * * * *"
      assert item["message"] == "Hourly"
      assert item["enabled"] == true
      assert item["last_run_at"] == nil
    end
  end

  describe "manage_schedule tool — create" do
    test "creates a schedule", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      assert {:ok, result} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "cron" => "*/10 * * * *",
        "message" => "Every 10 minutes"
      }, context)

      assert result["action"] == "created"
      assert result["success"] == true
      assert result["schedule"]["cron"] == "*/10 * * * *"
      assert result["schedule"]["message"] == "Every 10 minutes"
      assert result["schedule"]["enabled"] == true
      assert result["schedule"]["id"] != nil
      assert result["note"] =~ "successfully"
    end

    test "deduplicates when same cron + message already exists", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      # First create
      assert {:ok, first} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "cron" => "0 * * * *",
        "message" => "Hourly check"
      }, context)

      assert first["action"] == "created"

      # Second create with same cron + message — should return existing
      assert {:ok, second} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "cron" => "0 * * * *",
        "message" => "Hourly check"
      }, context)

      assert second["action"] == "already_exists"
      assert second["schedule"]["id"] == first["schedule"]["id"]

      # Verify only one schedule exists
      assert {:ok, %{"count" => 1}} = Tools.execute_tool("list_schedules", %{}, context)
    end

    test "creates a disabled schedule", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      assert {:ok, result} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "cron" => "0 9 * * *",
        "enabled" => false
      }, context)

      assert result["schedule"]["enabled"] == false
    end

    test "returns error for invalid cron", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      assert {:error, msg} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "cron" => "not a cron"
      }, context)

      assert msg =~ "cron"
    end

    test "returns error when cron is missing", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      assert {:error, msg} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "message" => "No cron provided"
      }, context)

      assert msg =~ "cron"
    end
  end

  describe "manage_schedule tool — update" do
    test "updates a schedule", %{scope: scope} do
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)
      context = %{agent: agent}

      assert {:ok, result} = Tools.execute_tool("manage_schedule", %{
        "action" => "update",
        "schedule_id" => schedule.id,
        "message" => "Updated message",
        "enabled" => false
      }, context)

      assert result["action"] == "updated"
      assert result["schedule"]["message"] == "Updated message"
      assert result["schedule"]["enabled"] == false
    end

    test "updates cron expression", %{scope: scope} do
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)
      context = %{agent: agent}

      assert {:ok, result} = Tools.execute_tool("manage_schedule", %{
        "action" => "update",
        "schedule_id" => schedule.id,
        "cron" => "0 0 * * *"
      }, context)

      assert result["schedule"]["cron"] == "0 0 * * *"
    end

    test "returns error when schedule_id is missing", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      assert {:error, "schedule_id is required for update"} =
        Tools.execute_tool("manage_schedule", %{"action" => "update", "message" => "New"}, context)
    end

    test "returns error when schedule not found", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      fake_id = Ecto.UUID.generate()
      assert {:error, msg} = Tools.execute_tool("manage_schedule", %{
        "action" => "update",
        "schedule_id" => fake_id
      }, context)

      assert msg =~ "Schedule not found"
    end

    test "cannot update another agent's schedule", %{scope: scope} do
      agent1 = agent_fixture(scope)
      agent2 = agent_fixture(scope)
      schedule = schedule_fixture(agent2)
      context = %{agent: agent1}

      assert {:error, msg} = Tools.execute_tool("manage_schedule", %{
        "action" => "update",
        "schedule_id" => schedule.id,
        "message" => "Hijacked"
      }, context)

      assert msg =~ "Schedule not found"
    end
  end

  describe "manage_schedule tool — delete" do
    test "deletes a schedule", %{scope: scope} do
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)
      context = %{agent: agent}

      assert {:ok, result} = Tools.execute_tool("manage_schedule", %{
        "action" => "delete",
        "schedule_id" => schedule.id
      }, context)

      assert result["deleted"] == true
      assert result["schedule_id"] == schedule.id

      # Verify it's actually deleted
      assert {:ok, %{"count" => 0}} = Tools.execute_tool("list_schedules", %{}, context)
    end

    test "returns error when schedule_id is missing", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      assert {:error, "schedule_id is required for delete"} =
        Tools.execute_tool("manage_schedule", %{"action" => "delete"}, context)
    end

    test "returns error when schedule not found", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      fake_id = Ecto.UUID.generate()
      assert {:error, msg} = Tools.execute_tool("manage_schedule", %{
        "action" => "delete",
        "schedule_id" => fake_id
      }, context)

      assert msg =~ "Schedule not found"
    end
  end

  describe "manage_schedule tool — error cases" do
    test "returns error for unknown action", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      assert {:error, msg} = Tools.execute_tool("manage_schedule", %{
        "action" => "pause"
      }, context)

      assert msg =~ "Unknown action"
    end

    test "returns error when action is missing", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      assert {:error, msg} = Tools.execute_tool("manage_schedule", %{}, context)
      assert msg =~ "Missing required parameter: action"
    end
  end
end
