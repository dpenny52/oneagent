defmodule OneAgentWeb.AgentJSON do
  alias OneAgent.Agents.{Agent, AgentBucket, AgentRun, AgentStep, AgentMemory}

  def render("index.json", %{agents: agents}) do
    %{data: Enum.map(agents, &agent_data/1)}
  end

  def render("show.json", %{agent: agent}) do
    %{data: agent_data(agent)}
  end

  def render("buckets.json", %{buckets: buckets}) do
    %{data: Enum.map(buckets, &bucket_data/1)}
  end

  def render("runs.json", %{runs: runs}) do
    %{data: Enum.map(runs, &run_data/1)}
  end

  def render("run.json", %{run: run}) do
    %{data: run_detail_data(run)}
  end

  def render("invoke.json", %{result: result}) do
    %{data: result}
  end

  def render("memories.json", %{memories: memories}) do
    %{data: Enum.map(memories, &memory_data/1)}
  end

  defp agent_data(%Agent{} = agent) do
    %{
      id: agent.id,
      name: agent.name,
      description: agent.description,
      status: agent.status,
      model_provider: agent.model_provider,
      model_id: agent.model_id,
      model_config: agent.model_config,
      trigger_type: agent.trigger_type,
      trigger_config: agent.trigger_config,
      max_steps_per_run: agent.max_steps_per_run,
      max_runs_per_day: agent.max_runs_per_day,
      llm_config_id: agent.llm_config_id,
      inserted_at: agent.inserted_at,
      updated_at: agent.updated_at
    }
  end

  defp bucket_data(%AgentBucket{} = bucket) do
    %{
      id: bucket.id,
      bucket: bucket.bucket,
      scope_config: bucket.scope_config,
      credential_id: bucket.credential_id,
      granted_at: bucket.granted_at,
      revoked_at: bucket.revoked_at
    }
  end

  defp run_data(%AgentRun{} = run) do
    %{
      id: run.id,
      status: run.status,
      trigger: run.trigger,
      started_at: run.started_at,
      completed_at: run.completed_at,
      total_tokens_used: run.total_tokens_used,
      total_steps: run.total_steps,
      error_message: run.error_message,
      inserted_at: run.inserted_at
    }
  end

  defp run_detail_data(%AgentRun{} = run) do
    base = run_data(run)

    steps = case run.steps do
      %Ecto.Association.NotLoaded{} -> []
      steps -> Enum.map(steps, &step_data/1)
    end

    Map.put(base, :steps, steps)
  end

  defp step_data(%AgentStep{} = step) do
    %{
      id: step.id,
      step_number: step.step_number,
      step_type: step.step_type,
      input: step.input,
      output: step.output,
      tool_id: step.tool_id,
      bucket: step.bucket,
      tokens_used: step.tokens_used,
      duration_ms: step.duration_ms,
      status: step.status
    }
  end

  defp memory_data(%AgentMemory{} = memory) do
    %{
      id: memory.id,
      key: memory.key,
      value: memory.value,
      memory_type: memory.memory_type,
      confidence: memory.confidence,
      expires_at: memory.expires_at,
      inserted_at: memory.inserted_at,
      updated_at: memory.updated_at
    }
  end
end
