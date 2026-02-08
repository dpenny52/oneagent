defmodule OneAgent.Tools.ListGoalsTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    %{agent: agent, context: %{agent: agent}}
  end

  describe "list_goals" do
    test "returns empty list when no goals", %{context: context} do
      assert {:ok, result} = Tools.execute_tool("list_goals", %{}, context)
      assert result["goals"] == []
      assert result["count"] == 0
    end

    test "returns active goals by default", %{agent: agent, context: context} do
      _active = goal_fixture(agent, %{title: "Active Goal"})
      _completed = goal_fixture(agent, %{title: "Completed Goal", status: "completed"})

      assert {:ok, result} = Tools.execute_tool("list_goals", %{}, context)
      assert result["count"] == 1
      assert hd(result["goals"])["title"] == "Active Goal"
    end

    test "returns all goals when active_only is false", %{agent: agent, context: context} do
      _active = goal_fixture(agent, %{title: "Active"})
      _completed = goal_fixture(agent, %{title: "Done", status: "completed"})
      _paused = goal_fixture(agent, %{title: "Paused", status: "paused"})

      assert {:ok, result} = Tools.execute_tool("list_goals", %{"active_only" => false}, context)
      assert result["count"] == 3
    end

    test "includes progress in summary", %{agent: agent, context: context} do
      goal = goal_fixture(agent)
      _s1 = goal_step_fixture(goal, %{title: "Done", status: "completed"})
      _s2 = goal_step_fixture(goal, %{title: "Pending"})

      assert {:ok, result} = Tools.execute_tool("list_goals", %{}, context)
      [summary] = result["goals"]
      assert summary["progress"] == "1/2"
    end
  end

  describe "single goal detail" do
    test "returns detailed goal by goal_id", %{agent: agent, context: context} do
      goal = goal_fixture(agent, %{title: "Detailed Goal", description: "Full info"})
      _step = goal_step_fixture(goal, %{title: "Step 1"})

      assert {:ok, result} = Tools.execute_tool("list_goals", %{"goal_id" => goal.id}, context)
      detail = result["goal"]
      assert detail["title"] == "Detailed Goal"
      assert detail["description"] == "Full info"
      assert length(detail["steps"]) == 1
      assert hd(detail["steps"])["title"] == "Step 1"
    end

    test "returns error for goal not found", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("list_goals", %{"goal_id" => Ecto.UUID.generate()}, context)
      assert msg =~ "Goal not found"
    end
  end
end
