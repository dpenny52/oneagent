defmodule OneAgent.Tools.StoreMemoryTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    %{agent: agent, context: %{agent: agent, run: nil}}
  end

  describe "execute" do
    test "stores a new memory", %{context: context} do
      assert {:ok, result} = Tools.execute_tool("store_memory", %{
        "key" => "user_timezone",
        "value" => %{"tz" => "US/Eastern"},
        "memory_type" => "preference"
      }, context)

      assert result["stored"] == true
      assert result["key"] == "user_timezone"
    end

    test "rejects creation when memory limit reached", %{agent: agent, context: context} do
      # Create 500 memories (the limit)
      for i <- 1..500 do
        agent_memory_fixture(agent, %{key: "memory_#{i}", value: %{"data" => i}})
      end

      assert {:error, msg} = Tools.execute_tool("store_memory", %{
        "key" => "one_too_many",
        "value" => %{"data" => "overflow"},
        "memory_type" => "fact"
      }, context)

      assert msg =~ "Memory limit reached"
      assert msg =~ "maximum 500"
    end

    test "allows upsert of existing key even at limit", %{agent: agent, context: context} do
      # Create 500 memories
      for i <- 1..500 do
        agent_memory_fixture(agent, %{key: "memory_#{i}", value: %{"data" => i}})
      end

      # Updating an existing key should succeed
      assert {:ok, result} = Tools.execute_tool("store_memory", %{
        "key" => "memory_1",
        "value" => %{"data" => "updated"},
        "memory_type" => "fact"
      }, context)

      assert result["stored"] == true
    end
  end
end
