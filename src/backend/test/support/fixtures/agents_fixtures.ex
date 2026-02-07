defmodule OneAgent.AgentsFixtures do
  @moduledoc """
  Test helpers for creating entities via the `OneAgent.Agents` context.
  """

  alias OneAgent.Agents
  alias OneAgent.AccountsFixtures

  def valid_agent_attributes(attrs \\ %{}) do
    Map.merge(%{
      "name" => "Test Agent #{System.unique_integer([:positive])}",
      "description" => "A test agent",
      "system_prompt" => "You are a helpful test agent.",
      "model_provider" => "anthropic",
      "model_id" => "claude-sonnet-4-5-20250929"
    }, attrs)
  end

  def agent_fixture(scope, attrs \\ %{}) do
    {:ok, agent} =
      attrs
      |> valid_agent_attributes()
      |> then(&Agents.create_agent(scope, &1))

    agent
  end

  def agent_with_buckets_fixture(scope, buckets \\ ["web_access"]) do
    agent = agent_fixture(scope)

    Enum.each(buckets, fn bucket ->
      {:ok, _} = Agents.grant_bucket(agent, %{bucket: bucket})
    end)

    agent
  end

  def agent_run_fixture(agent, attrs \\ %{}) do
    attrs = Map.merge(%{trigger: "manual"}, attrs)
    {:ok, run} = Agents.create_run(agent, attrs)
    run
  end

  def agent_step_fixture(run, attrs \\ %{}) do
    attrs = Map.merge(%{
      step_number: 1,
      step_type: "llm_call",
      input: %{"message_count" => 1},
      output: %{"stop_reason" => "end_turn"},
      tokens_used: 100,
      duration_ms: 500
    }, attrs)

    {:ok, step} = Agents.create_step(run, attrs)
    step
  end

  def agent_memory_fixture(agent, attrs \\ %{}) do
    attrs = Map.merge(%{
      key: "test_key_#{System.unique_integer([:positive])}",
      value: %{"data" => "test value"},
      memory_type: "fact"
    }, attrs)

    {:ok, memory} = Agents.upsert_memory(agent, attrs)
    memory
  end

  def schedule_fixture(agent, attrs \\ %{}) do
    attrs = Map.merge(%{
      "cron" => "*/5 * * * *",
      "message" => "Run scheduled task"
    }, attrs)

    {:ok, schedule} = Agents.create_schedule(agent, attrs)
    schedule
  end

  def message_fixture(agent, attrs \\ %{}) do
    attrs = Map.merge(%{
      role: "user",
      content: "test message #{System.unique_integer([:positive])}"
    }, attrs)

    {:ok, message} = Agents.create_message(agent, attrs)
    message
  end

  def scope_fixture do
    user = AccountsFixtures.confirmed_user_fixture()
    OneAgent.Accounts.Scope.for_user(user)
  end
end
