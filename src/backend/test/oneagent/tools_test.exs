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
      assert length(tools) == 15

      ids = Enum.map(tools, & &1.id())
      assert "http_request" in ids
      assert "read_webpage" in ids
      assert "send_email" in ids
      assert "check_email" in ids
      assert "web_search" in ids
      assert "store_memory" in ids
      assert "recall_memory" in ids
      assert "list_schedules" in ids
      assert "manage_schedule" in ids
      assert "manage_goal" in ids
      assert "manage_goal_step" in ids
      assert "list_goals" in ids
      assert "send_whatsapp" in ids
      assert "send_telegram" in ids
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
    end

    test "excludes http_request when neither web_access nor data_write granted", %{scope: scope} do
      agent = agent_fixture(scope)

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

      refute "http_request" in names
    end

    test "includes http_request when web_access is granted", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "web_access"})

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

      assert "http_request" in names
    end

    test "includes http_request when data_write is granted", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "data_write"})

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

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

    test "includes web_search when web_search bucket is granted", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "web_search"})

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

      assert "web_search" in names
    end

    test "excludes web_search when web_search bucket not granted", %{scope: scope} do
      agent = agent_fixture(scope)

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

      refute "web_search" in names
    end

    test "includes send_whatsapp when whatsapp bucket is granted", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "whatsapp"})

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

      assert "send_whatsapp" in names
    end

    test "excludes send_whatsapp when whatsapp bucket not granted", %{scope: scope} do
      agent = agent_fixture(scope)

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

      refute "send_whatsapp" in names
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

    test "recall with search finds matching memories", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil}

      Tools.execute_tool("store_memory", %{
        "key" => "user_preference", "value" => %{"likes" => "dark chocolate"}, "memory_type" => "preference"
      }, context)

      Tools.execute_tool("store_memory", %{
        "key" => "random_fact", "value" => %{"info" => "the sky is blue"}, "memory_type" => "fact"
      }, context)

      assert {:ok, result} = Tools.execute_tool("recall_memory", %{"search" => "chocolate"}, context)
      assert result["count"] == 1
      assert result["query"] == "chocolate"
      [item] = result["memories"]
      assert item["key"] == "user_preference"
      assert is_number(item["relevance"])
    end

    test "recall with search returns empty for no matches", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil}

      Tools.execute_tool("store_memory", %{
        "key" => "k1", "value" => %{"a" => "hello"}, "memory_type" => "fact"
      }, context)

      assert {:ok, result} = Tools.execute_tool("recall_memory", %{"search" => "xylophone"}, context)
      assert result["count"] == 0
      assert result["memories"] == []
    end

    test "recall key takes priority over search", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil}

      Tools.execute_tool("store_memory", %{
        "key" => "specific_key", "value" => %{"data" => "specific"}, "memory_type" => "fact"
      }, context)

      # Both key and search provided — key wins
      assert {:ok, result} = Tools.execute_tool("recall_memory", %{"key" => "specific_key", "search" => "specific"}, context)
      assert result["found"] == true
      assert result["key"] == "specific_key"
      refute Map.has_key?(result, "memories")
    end

    test "recall empty search falls through to list-all", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil}

      Tools.execute_tool("store_memory", %{
        "key" => "k1", "value" => %{"a" => 1}, "memory_type" => "fact"
      }, context)

      assert {:ok, result} = Tools.execute_tool("recall_memory", %{"search" => "  "}, context)
      assert result["count"] == 1
      assert is_list(result["memories"])
      refute Map.has_key?(result, "query")
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

  describe "webhook trigger restrictions" do
    test "blocks manage_schedule create from webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, trigger: "webhook"}

      assert {:error, msg} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "cron" => "*/5 * * * *",
        "message" => "Injected schedule"
      }, context)

      assert msg =~ "not available during webhook-triggered runs"
    end

    test "blocks manage_schedule delete from webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)
      context = %{agent: agent, trigger: "webhook"}

      assert {:error, msg} = Tools.execute_tool("manage_schedule", %{
        "action" => "delete",
        "schedule_id" => schedule.id
      }, context)

      assert msg =~ "not available during webhook-triggered runs"
    end

    test "blocks manage_schedule update from webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)
      context = %{agent: agent, trigger: "webhook"}

      assert {:error, msg} = Tools.execute_tool("manage_schedule", %{
        "action" => "update",
        "schedule_id" => schedule.id,
        "enabled" => false
      }, context)

      assert msg =~ "not available during webhook-triggered runs"
    end

    test "blocks manage_goal create from webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, trigger: "webhook"}

      assert {:error, msg} = Tools.execute_tool("manage_goal", %{
        "action" => "create",
        "title" => "Injected goal"
      }, context)

      assert msg =~ "not available during webhook-triggered runs"
    end

    test "blocks manage_goal delete from webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, trigger: "webhook"}

      assert {:error, msg} = Tools.execute_tool("manage_goal", %{
        "action" => "delete",
        "goal_id" => Ecto.UUID.generate()
      }, context)

      assert msg =~ "not available during webhook-triggered runs"
    end

    test "blocks manage_goal abandon from webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, trigger: "webhook"}

      assert {:error, msg} = Tools.execute_tool("manage_goal", %{
        "action" => "abandon",
        "goal_id" => Ecto.UUID.generate()
      }, context)

      assert msg =~ "not available during webhook-triggered runs"
    end

    test "blocks manage_goal_step remove from webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, trigger: "webhook"}

      assert {:error, msg} = Tools.execute_tool("manage_goal_step", %{
        "action" => "remove",
        "goal_id" => Ecto.UUID.generate(),
        "step_id" => Ecto.UUID.generate()
      }, context)

      assert msg =~ "not available during webhook-triggered runs"
    end

    test "blocks send_whatsapp from webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "whatsapp"})
      context = %{agent: agent, trigger: "webhook"}

      assert {:error, msg} = Tools.execute_tool("send_whatsapp", %{
        "to" => "15551234567",
        "message" => "Injected message"
      }, context)

      assert msg =~ "not available during webhook-triggered runs"
    end

    test "blocks store_memory from webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil, trigger: "webhook"}

      assert {:error, msg} = Tools.execute_tool("store_memory", %{
        "key" => "injected_key",
        "value" => "injected_value",
        "memory_type" => "fact"
      }, context)

      assert msg =~ "not available during webhook-triggered runs"
    end

    test "allows recall_memory from webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil, trigger: "webhook"}

      assert {:ok, result} = Tools.execute_tool("recall_memory", %{}, context)
      assert result["count"] == 0
    end

    test "allows list_schedules from webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, trigger: "webhook"}

      assert {:ok, result} = Tools.execute_tool("list_schedules", %{}, context)
      assert result["count"] == 0
    end

    test "allows list_goals from webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, trigger: "webhook"}

      assert {:ok, result} = Tools.execute_tool("list_goals", %{}, context)
      assert result["count"] == 0
    end

    test "allows manage_schedule from manual trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, trigger: "manual"}

      assert {:ok, result} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "cron" => "*/5 * * * *",
        "message" => "Allowed schedule"
      }, context)

      assert result["action"] == "created"
    end

    test "allows manage_schedule from scheduled trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, trigger: "scheduled"}

      assert {:ok, result} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "cron" => "0 9 * * *",
        "message" => "Self-managed schedule"
      }, context)

      assert result["action"] == "created"
    end

    test "allows store_memory without trigger in context", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil}

      assert {:ok, %{"stored" => true}} = Tools.execute_tool("store_memory", %{
        "key" => "normal_key",
        "value" => %{"data" => "normal_value"},
        "memory_type" => "fact"
      }, context)
    end

    test "trusted sender bypasses manage_schedule create restriction on webhook", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, trigger: "webhook", trusted_sender: true}

      assert {:ok, result} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "cron" => "*/5 * * * *",
        "message" => "Trusted schedule"
      }, context)

      assert result["action"] == "created"
    end

    test "trusted sender bypasses store_memory restriction on webhook", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, run: nil, trigger: "webhook", trusted_sender: true}

      assert {:ok, %{"stored" => true}} = Tools.execute_tool("store_memory", %{
        "key" => "trusted_key",
        "value" => %{"data" => "trusted_value"},
        "memory_type" => "fact"
      }, context)
    end

    test "trusted sender bypasses send_telegram restriction on webhook", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "telegram"})
      context = %{agent: agent, trigger: "webhook", trusted_sender: true}

      # Will fail at credential lookup, but should NOT fail at webhook restriction
      result = Tools.execute_tool("send_telegram", %{
        "chat_id" => "12345",
        "message" => "Trusted message"
      }, context)

      # Should get past the webhook restriction check — credential error is expected
      case result do
        {:error, msg} -> refute msg =~ "not available during webhook-triggered runs"
        {:ok, _} -> :ok
      end
    end

    test "trusted sender bypasses manage_calendar create restriction on webhook", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "google_calendar"})
      context = %{agent: agent, trigger: "webhook", trusted_sender: true}

      # Will fail at credential lookup, not at webhook restriction
      result = Tools.execute_tool("manage_calendar", %{
        "action" => "create_event",
        "title" => "Test Event",
        "start_time" => "2026-03-01T10:00:00Z",
        "end_time" => "2026-03-01T11:00:00Z"
      }, context)

      case result do
        {:error, msg} -> refute msg =~ "not available during webhook-triggered runs"
        {:ok, _} -> :ok
      end
    end

    test "untrusted webhook still blocks when trusted_sender is false", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent, trigger: "webhook", trusted_sender: false}

      assert {:error, msg} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "cron" => "*/5 * * * *",
        "message" => "Untrusted schedule"
      }, context)

      assert msg =~ "not available during webhook-triggered runs"
    end
  end

  describe "tool_definitions_for_agent/2 webhook filtering" do
    test "excludes send_whatsapp from tool definitions for webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "whatsapp"})

      defs = Tools.tool_definitions_for_agent(agent, "webhook")
      names = Enum.map(defs, & &1["name"])

      refute "send_whatsapp" in names
    end

    test "excludes store_memory from tool definitions for webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)

      defs = Tools.tool_definitions_for_agent(agent, "webhook")
      names = Enum.map(defs, & &1["name"])

      refute "store_memory" in names
      # Read-only tools remain
      assert "recall_memory" in names
      assert "list_schedules" in names
      assert "list_goals" in names
      # Action-based tools still visible (restricted at execution time)
      assert "manage_schedule" in names
      assert "manage_goal" in names
    end

    test "includes all tools for manual trigger", %{scope: scope} do
      agent = agent_fixture(scope)

      defs = Tools.tool_definitions_for_agent(agent, "manual")
      names = Enum.map(defs, & &1["name"])

      assert "store_memory" in names
      assert "recall_memory" in names
      assert "manage_schedule" in names
    end

    test "includes all tools when trigger not specified (default)", %{scope: scope} do
      agent = agent_fixture(scope)

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

      assert "store_memory" in names
      assert "recall_memory" in names
    end

    test "trusted sender gets all tools including send_whatsapp for webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "whatsapp"})

      defs = Tools.tool_definitions_for_agent(agent, "webhook", %{trusted_sender: true})
      names = Enum.map(defs, & &1["name"])

      assert "send_whatsapp" in names
    end

    test "trusted sender gets store_memory for webhook trigger", %{scope: scope} do
      agent = agent_fixture(scope)

      defs = Tools.tool_definitions_for_agent(agent, "webhook", %{trusted_sender: true})
      names = Enum.map(defs, & &1["name"])

      assert "store_memory" in names
    end

    test "untrusted webhook still excludes send_whatsapp from definitions", %{scope: scope} do
      agent = agent_fixture(scope)
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: "whatsapp"})

      defs = Tools.tool_definitions_for_agent(agent, "webhook", %{trusted_sender: false})
      names = Enum.map(defs, & &1["name"])

      refute "send_whatsapp" in names
    end
  end
end
