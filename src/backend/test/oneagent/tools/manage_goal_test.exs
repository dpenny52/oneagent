defmodule OneAgent.Tools.ManageGoalTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools
  alias OneAgent.Agents

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    %{agent: agent, context: %{agent: agent}}
  end

  describe "create" do
    test "creates a goal without steps", %{context: context} do
      assert {:ok, result} = Tools.execute_tool("manage_goal", %{
        "action" => "create",
        "title" => "Find a job",
        "description" => "Help user find employment",
        "priority" => 2
      }, context)

      assert result["action"] == "created"
      assert result["success"] == true
      assert result["goal"]["title"] == "Find a job"
      assert result["goal"]["priority"] == 2
      assert result["steps_created"] == 0
      assert result["review_schedule_id"] != nil
      assert result["note"] =~ "successfully"
    end

    test "creates a goal with steps (no cron)", %{context: context} do
      assert {:ok, result} = Tools.execute_tool("manage_goal", %{
        "action" => "create",
        "title" => "Learn Elixir",
        "steps" => [
          %{"title" => "Read the docs"},
          %{"title" => "Build a project"}
        ]
      }, context)

      assert result["steps_created"] == 2
      steps = result["goal"]["steps"]
      assert length(steps) == 2
      assert Enum.at(steps, 0)["title"] == "Read the docs"
      assert Enum.at(steps, 1)["title"] == "Build a project"
      # No cron, so no schedule_id
      assert Enum.all?(steps, fn s -> s["schedule_id"] == nil end)
    end

    test "creates a goal with steps that have cron schedules", %{agent: agent, context: context} do
      assert {:ok, result} = Tools.execute_tool("manage_goal", %{
        "action" => "create",
        "title" => "Monitor news",
        "steps" => [
          %{"title" => "Check tech news", "cron" => "0 9 * * *", "message" => "Check tech headlines"},
          %{"title" => "Summarize findings"}
        ]
      }, context)

      assert result["steps_created"] == 2
      steps = result["goal"]["steps"]

      # First step should have a linked schedule
      scheduled_step = Enum.find(steps, &(&1["title"] == "Check tech news"))
      assert scheduled_step["schedule_id"] != nil

      # Verify the schedule was actually created
      {:ok, sched} = Agents.get_schedule(agent, scheduled_step["schedule_id"])
      assert sched.cron == "0 9 * * *"
      assert sched.message == "Check tech headlines"

      # Second step should have no schedule
      plain_step = Enum.find(steps, &(&1["title"] == "Summarize findings"))
      assert plain_step["schedule_id"] == nil
    end

    test "creates auto review schedule on every goal creation", %{agent: agent, context: context} do
      assert {:ok, result} = Tools.execute_tool("manage_goal", %{
        "action" => "create",
        "title" => "Test goal"
      }, context)

      review_id = result["review_schedule_id"]
      assert review_id != nil

      {:ok, sched} = Agents.get_schedule(agent, review_id)
      assert sched.cron == "0 * * * *"
      assert sched.message =~ "Review goal"
      assert sched.message =~ "Test goal"
    end

    test "returns error for missing title", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal", %{
        "action" => "create"
      }, context)

      assert msg =~ "Missing required parameter: title"
    end

    test "returns error for empty title", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal", %{
        "action" => "create",
        "title" => "  "
      }, context)

      assert msg =~ "Missing required parameter: title"
    end
  end

  describe "update" do
    test "updates a goal", %{agent: agent, context: context} do
      goal = goal_fixture(agent)

      assert {:ok, result} = Tools.execute_tool("manage_goal", %{
        "action" => "update",
        "goal_id" => goal.id,
        "title" => "Updated Title",
        "priority" => 5
      }, context)

      assert result["action"] == "updated"
      assert result["goal"]["title"] == "Updated Title"
      assert result["goal"]["priority"] == 5
    end

    test "returns error when goal_id missing", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal", %{
        "action" => "update",
        "title" => "New"
      }, context)

      assert msg =~ "goal_id is required"
    end

    test "returns error when goal not found", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal", %{
        "action" => "update",
        "goal_id" => Ecto.UUID.generate()
      }, context)

      assert msg =~ "Goal not found"
    end
  end

  describe "complete" do
    test "completes a goal and disables schedules", %{agent: agent, context: context} do
      goal = goal_fixture(agent)
      _step = goal_step_fixture(goal, %{title: "Pending step"})

      # Create and link review schedule
      review = schedule_fixture(agent, %{"cron" => "0 * * * *", "message" => "Review"})
      {:ok, goal} = Agents.update_goal(goal, %{review_schedule_id: review.id})

      assert {:ok, result} = Tools.execute_tool("manage_goal", %{
        "action" => "complete",
        "goal_id" => goal.id
      }, context)

      assert result["action"] == "completed"
      assert result["success"] == true

      # Verify schedule disabled
      {:ok, sched} = Agents.get_schedule(agent, review.id)
      assert sched.enabled == false
    end
  end

  describe "pause and resume" do
    test "pauses and resumes a goal", %{agent: agent, context: context} do
      goal = goal_fixture(agent)
      review = schedule_fixture(agent, %{"cron" => "0 * * * *", "message" => "Review"})
      {:ok, goal} = Agents.update_goal(goal, %{review_schedule_id: review.id})

      # Pause
      assert {:ok, result} = Tools.execute_tool("manage_goal", %{
        "action" => "pause",
        "goal_id" => goal.id
      }, context)

      assert result["action"] == "paused"

      {:ok, sched} = Agents.get_schedule(agent, review.id)
      assert sched.enabled == false

      # Resume
      assert {:ok, result} = Tools.execute_tool("manage_goal", %{
        "action" => "resume",
        "goal_id" => goal.id
      }, context)

      assert result["action"] == "resumed"

      {:ok, sched} = Agents.get_schedule(agent, review.id)
      assert sched.enabled == true
    end
  end

  describe "abandon" do
    test "abandons a goal and disables schedules", %{agent: agent, context: context} do
      goal = goal_fixture(agent)
      _step = goal_step_fixture(goal, %{title: "Pending"})
      review = schedule_fixture(agent, %{"cron" => "0 * * * *", "message" => "Review"})
      {:ok, goal} = Agents.update_goal(goal, %{review_schedule_id: review.id})

      assert {:ok, result} = Tools.execute_tool("manage_goal", %{
        "action" => "abandon",
        "goal_id" => goal.id
      }, context)

      assert result["action"] == "abandoned"

      {:ok, sched} = Agents.get_schedule(agent, review.id)
      assert sched.enabled == false
    end
  end

  describe "delete" do
    test "deletes a goal and associated schedules", %{agent: agent, context: context} do
      goal = goal_fixture(agent)
      step_sched = schedule_fixture(agent, %{"cron" => "0 9 * * *", "message" => "Step work"})
      {:ok, _step} = Agents.create_goal_step(goal, %{title: "Sched step", schedule_id: step_sched.id})
      review = schedule_fixture(agent, %{"cron" => "0 * * * *", "message" => "Review"})
      {:ok, _goal} = Agents.update_goal(goal, %{review_schedule_id: review.id})

      assert {:ok, result} = Tools.execute_tool("manage_goal", %{
        "action" => "delete",
        "goal_id" => goal.id
      }, context)

      assert result["action"] == "deleted"
      assert {:error, :not_found} = Agents.get_goal(agent, goal.id)
      assert {:error, :not_found} = Agents.get_schedule(agent, step_sched.id)
      assert {:error, :not_found} = Agents.get_schedule(agent, review.id)
    end
  end

  describe "error cases" do
    test "returns error for unknown action", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal", %{
        "action" => "explode"
      }, context)

      assert msg =~ "Unknown action"
    end

    test "returns error when action is missing", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal", %{}, context)
      assert msg =~ "Missing required parameter: action"
    end

    test "returns error for missing goal_id on complete", %{context: context} do
      assert {:error, msg} = Tools.execute_tool("manage_goal", %{
        "action" => "complete"
      }, context)

      assert msg =~ "goal_id is required"
    end
  end
end
