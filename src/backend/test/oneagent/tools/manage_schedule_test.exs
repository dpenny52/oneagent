defmodule OneAgent.Tools.ManageScheduleTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    %{agent: agent, context: %{agent: agent}}
  end

  describe "create" do
    test "creates a schedule", %{context: context} do
      assert {:ok, result} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "cron" => "*/5 * * * *",
        "message" => "Check for updates"
      }, context)

      assert result["action"] == "created"
      assert result["success"] == true
      assert result["schedule"]["cron"] == "*/5 * * * *"
    end

    test "rejects creation when schedule limit reached", %{agent: agent, context: context} do
      # Create 50 schedules (the limit)
      for i <- 1..50 do
        schedule_fixture(agent, %{"cron" => "#{rem(i, 60)} * * * *", "message" => "Schedule #{i}"})
      end

      assert {:error, msg} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "cron" => "0 0 * * *",
        "message" => "One too many"
      }, context)

      assert msg =~ "Schedule limit reached"
      assert msg =~ "maximum 50"
    end

    test "dedup bypasses limit check", %{agent: agent, context: context} do
      # Create 50 schedules
      for i <- 1..50 do
        schedule_fixture(agent, %{"cron" => "#{rem(i, 60)} * * * *", "message" => "Schedule #{i}"})
      end

      # Creating a duplicate of an existing schedule should succeed (returns existing, no new creation)
      assert {:ok, result} = Tools.execute_tool("manage_schedule", %{
        "action" => "create",
        "cron" => "1 * * * *",
        "message" => "Schedule 1"
      }, context)

      assert result["action"] == "already_exists"
    end
  end
end
