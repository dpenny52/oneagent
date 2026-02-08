defmodule OneAgent.Tools.ManageGoalStepTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools
  alias OneAgent.Agents

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    goal = goal_fixture(agent)
    %{agent: agent, goal: goal, context: %{agent: agent}}
  end

  describe "add" do
    test "adds a step to a goal", %{goal: goal, context: context} do
      assert {:ok, result} = Tools.execute_tool("manage_goal_step", %{
        "action" => "add",
        "goal_id" => goal.id,
        "title" => "New step",
        "description" => "Do something"
      }, context)

      assert result["action"] == "added"
      assert result["step"]["title"] == "New step"
      assert result["step"]["status"] == "pending"
      assert result["step"]["position"] == 1
    end

    test "adds a step with cron schedule", %{agent: agent, goal: goal, context: context} do
      assert {:ok, result} = Tools.execute_tool("manage_goal_step", %{
        "action" => "add",
        "goal_id" => goal.id,
        "title" => "Daily task",
        "cron" => "0 9 * * *",
        "message" => "Run daily"
      }, context)

      assert result["step"]["schedule_id"] != nil

      {:ok, sched} = Agents.get_schedule(agent, result["step"]["schedule_id"])
      assert sched.cron == "0 9 * * *"
    end

    test "returns error for missing goal_id", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal_step", %{
        "action" => "add",
        "title" => "Step"
      }, context)

      assert msg =~ "goal_id is required"
    end

    test "returns error for missing title", %{goal: goal, context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal_step", %{
        "action" => "add",
        "goal_id" => goal.id
      }, context)

      assert msg =~ "Missing required parameter: title"
    end

    test "returns error for goal not found", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal_step", %{
        "action" => "add",
        "goal_id" => Ecto.UUID.generate(),
        "title" => "Step"
      }, context)

      assert msg =~ "Goal not found"
    end
  end

  describe "update" do
    test "updates a step", %{goal: goal, context: context} do
      step = goal_step_fixture(goal)

      assert {:ok, result} = Tools.execute_tool("manage_goal_step", %{
        "action" => "update",
        "step_id" => step.id,
        "title" => "Updated title"
      }, context)

      assert result["action"] == "updated"
      assert result["step"]["title"] == "Updated title"
    end

    test "returns error for missing step_id", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal_step", %{
        "action" => "update",
        "title" => "New"
      }, context)

      assert msg =~ "step_id is required"
    end
  end

  describe "complete" do
    test "completes a step with result_notes", %{goal: goal, context: context} do
      step = goal_step_fixture(goal)

      assert {:ok, result} = Tools.execute_tool("manage_goal_step", %{
        "action" => "complete",
        "step_id" => step.id,
        "result_notes" => "Task finished successfully"
      }, context)

      assert result["action"] == "completed"
      assert result["step"]["status"] == "completed"
      assert result["step"]["result_notes"] == "Task finished successfully"
    end
  end

  describe "skip" do
    test "skips a step", %{goal: goal, context: context} do
      step = goal_step_fixture(goal)

      assert {:ok, result} = Tools.execute_tool("manage_goal_step", %{
        "action" => "skip",
        "step_id" => step.id,
        "result_notes" => "Not applicable"
      }, context)

      assert result["action"] == "skipped"
      assert result["step"]["status"] == "skipped"
    end
  end

  describe "reorder" do
    test "reorders a step", %{goal: goal, context: context} do
      step = goal_step_fixture(goal)

      assert {:ok, result} = Tools.execute_tool("manage_goal_step", %{
        "action" => "reorder",
        "step_id" => step.id,
        "position" => 5
      }, context)

      assert result["action"] == "reordered"
      assert result["step"]["position"] == 5
    end

    test "returns error for missing position", %{goal: goal, context: context} do
      step = goal_step_fixture(goal)

      assert {:error, msg} = Tools.execute_tool("manage_goal_step", %{
        "action" => "reorder",
        "step_id" => step.id
      }, context)

      assert msg =~ "position is required"
    end
  end

  describe "remove" do
    test "removes a step", %{goal: goal, context: context} do
      step = goal_step_fixture(goal)

      assert {:ok, result} = Tools.execute_tool("manage_goal_step", %{
        "action" => "remove",
        "step_id" => step.id
      }, context)

      assert result["action"] == "removed"
      assert result["step_id"] == step.id
    end
  end

  describe "add_schedule" do
    test "adds a schedule to a step", %{agent: agent, goal: goal, context: context} do
      step = goal_step_fixture(goal)

      assert {:ok, result} = Tools.execute_tool("manage_goal_step", %{
        "action" => "add_schedule",
        "step_id" => step.id,
        "cron" => "0 12 * * *",
        "message" => "Noon check"
      }, context)

      assert result["action"] == "schedule_added"
      assert result["schedule_id"] != nil

      {:ok, sched} = Agents.get_schedule(agent, result["schedule_id"])
      assert sched.cron == "0 12 * * *"
    end

    test "replaces existing schedule", %{agent: agent, goal: goal, context: context} do
      sched = schedule_fixture(agent, %{"cron" => "0 9 * * *"})
      {:ok, step} = Agents.create_goal_step(goal, %{title: "Has schedule", schedule_id: sched.id})

      assert {:ok, result} = Tools.execute_tool("manage_goal_step", %{
        "action" => "add_schedule",
        "step_id" => step.id,
        "cron" => "0 18 * * *"
      }, context)

      assert result["schedule_id"] != sched.id

      # Old schedule should be deleted
      assert {:error, :not_found} = Agents.get_schedule(agent, sched.id)
    end

    test "returns error for missing cron", %{goal: goal, context: context} do
      step = goal_step_fixture(goal)

      assert {:error, msg} = Tools.execute_tool("manage_goal_step", %{
        "action" => "add_schedule",
        "step_id" => step.id
      }, context)

      assert msg =~ "cron is required"
    end
  end

  describe "remove_schedule" do
    test "removes a schedule from a step", %{agent: agent, goal: goal, context: context} do
      sched = schedule_fixture(agent, %{"cron" => "0 9 * * *"})
      {:ok, step} = Agents.create_goal_step(goal, %{title: "Has sched", schedule_id: sched.id})

      assert {:ok, result} = Tools.execute_tool("manage_goal_step", %{
        "action" => "remove_schedule",
        "step_id" => step.id
      }, context)

      assert result["action"] == "schedule_removed"
      assert result["step"]["schedule_id"] == nil

      # Schedule should be deleted
      assert {:error, :not_found} = Agents.get_schedule(agent, sched.id)
    end

    test "returns error when step has no schedule", %{goal: goal, context: context} do
      step = goal_step_fixture(goal)

      assert {:error, msg} = Tools.execute_tool("manage_goal_step", %{
        "action" => "remove_schedule",
        "step_id" => step.id
      }, context)

      assert msg =~ "no linked schedule"
    end
  end

  describe "error cases" do
    test "returns error for unknown action", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal_step", %{
        "action" => "explode"
      }, context)

      assert msg =~ "Unknown action"
    end

    test "returns error for missing action", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal_step", %{}, context)
      assert msg =~ "Missing required parameter: action"
    end

    test "returns error for step not found", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal_step", %{
        "action" => "update",
        "step_id" => Ecto.UUID.generate()
      }, context)

      assert msg =~ "Step not found"
    end
  end
end
