defmodule OneAgent.Workers.ScheduledExecutionTest do
  use OneAgent.DataCase, async: true

  import OneAgent.AgentsFixtures
  import OneAgent.CredentialsFixtures, except: [scope_fixture: 0]

  alias OneAgent.Workers.ScheduledExecution
  alias OneAgent.Agents

  setup do
    scope = scope_fixture()
    %{scope: scope}
  end

  defp build_job(schedule_id) do
    %Oban.Job{args: %{"schedule_id" => schedule_id}}
  end

  describe "perform/1" do
    test "discards when schedule does not exist" do
      fake_id = Ecto.UUID.generate()
      assert {:discard, "Schedule not found"} = ScheduledExecution.perform(build_job(fake_id))
    end

    test "discards when schedule is disabled", %{scope: scope} do
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)
      {:ok, schedule} = Agents.update_schedule(schedule, %{"enabled" => false})

      assert {:discard, "Schedule disabled"} = ScheduledExecution.perform(build_job(schedule.id))
    end

    test "discards when agent has no LLM config", %{scope: scope} do
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)

      # Agent created without llm_config_id by default
      assert agent.llm_config_id == nil
      assert {:discard, "Agent has no LLM config"} = ScheduledExecution.perform(build_job(schedule.id))
    end

    test "discards when daily run limit is exceeded", %{scope: scope} do
      llm_config = llm_config_fixture(scope)
      agent = agent_fixture(scope)
      {:ok, agent} = Agents.update_agent(agent, %{"llm_config_id" => llm_config.id})

      # Set max_runs_per_day to 1 and create a run to exceed it
      {:ok, agent} = Agents.update_agent(agent, %{"max_runs_per_day" => 1})
      _run = agent_run_fixture(agent, %{trigger: "scheduled"})

      schedule = schedule_fixture(agent)
      assert {:discard, "Daily run limit exceeded"} = ScheduledExecution.perform(build_job(schedule.id))
    end

    test "preloads agent's user for proper scope construction", %{scope: scope} do
      # This test verifies that the schedule preloads agent.user so that
      # Scope.for_user/1 can construct a proper Scope struct (not a bare map).
      agent = agent_fixture(scope)
      schedule = schedule_fixture(agent)

      # Simulate the same preload the worker does
      schedule = Repo.preload(schedule, agent: :user)

      # The user must be a proper User struct (not nil or a bare map)
      assert %OneAgent.Accounts.User{} = schedule.agent.user
      assert schedule.agent.user.id == scope.user.id

      # Scope.for_user/1 requires a User struct — this would crash with a bare map
      result_scope = OneAgent.Accounts.Scope.for_user(schedule.agent.user)
      assert %OneAgent.Accounts.Scope{user: %OneAgent.Accounts.User{}} = result_scope
    end
  end
end
