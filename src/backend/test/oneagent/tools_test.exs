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
      assert length(tools) == 5

      ids = Enum.map(tools, & &1.id())
      assert "http_request" in ids
      assert "read_webpage" in ids
      assert "send_email" in ids
      assert "store_memory" in ids
      assert "recall_memory" in ids
    end
  end

  describe "get_tool/1" do
    test "finds tool by id" do
      assert Tools.get_tool("http_request") == OneAgent.Tools.HttpRequest
      assert Tools.get_tool("store_memory") == OneAgent.Tools.StoreMemory
    end

    test "returns nil for unknown tool" do
      assert Tools.get_tool("nonexistent") == nil
    end
  end

  describe "tool_definitions_for_agent/1" do
    test "includes memory tools regardless of buckets", %{scope: scope} do
      agent = agent_fixture(scope)
      # Agent has no buckets granted

      defs = Tools.tool_definitions_for_agent(agent)
      names = Enum.map(defs, & &1["name"])

      assert "store_memory" in names
      assert "recall_memory" in names
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

    test "returns error for unknown tool", %{scope: scope} do
      agent = agent_fixture(scope)
      context = %{agent: agent}

      assert {:error, "Unknown tool: nonexistent"} =
        Tools.execute_tool("nonexistent", %{}, context)
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
  end
end
