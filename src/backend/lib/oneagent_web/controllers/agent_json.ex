defmodule OneAgentWeb.AgentJSON do
  alias OneAgent.Agents.{Agent, AgentBucket, AgentRun, AgentStep, AgentMemory, AgentMessage, AgentSchedule, AgentGoal, AgentGoalStep}

  def render("index.json", %{agents_with_runs: agents_with_runs}) do
    %{data: Enum.map(agents_with_runs, fn {agent, last_run} ->
      agent_data(agent) |> Map.put(:last_run, last_run_data(last_run))
    end)}
  end

  def render("index.json", %{agents: agents}) do
    %{data: Enum.map(agents, &agent_data/1)}
  end

  def render("show.json", %{agent: agent}) do
    %{data: agent_data(agent)}
  end

  def render("buckets.json", %{buckets: buckets}) do
    %{data: Enum.map(buckets, &bucket_data/1)}
  end

  def render("runs.json", %{runs: runs, meta: meta}) do
    %{data: Enum.map(runs, &run_data/1), meta: meta}
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

  def render("messages_list.json", %{messages: messages}) do
    %{data: Enum.map(messages, &message_data/1)}
  end

  def render("schedules.json", %{schedules: schedules}) do
    %{data: Enum.map(schedules, &schedule_data/1)}
  end

  def render("schedule.json", %{schedule: schedule}) do
    %{data: schedule_data(schedule)}
  end

  def render("goals.json", %{goals: goals}) do
    %{data: Enum.map(goals, &goal_data/1)}
  end

  defp agent_data(%Agent{} = agent) do
    %{
      id: agent.id,
      name: agent.name,
      description: agent.description,
      system_prompt: agent.system_prompt,
      model_provider: agent.model_provider,
      model_id: agent.model_id,
      model_config: agent.model_config,
      max_steps_per_run: agent.max_steps_per_run,
      max_runs_per_day: agent.max_runs_per_day,
      max_history_messages: agent.max_history_messages,
      llm_config_id: agent.llm_config_id,
      has_llm_config: agent.llm_config_id != nil,
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

  defp message_data(%AgentMessage{} = message) do
    %{
      id: message.id,
      role: message.role,
      content: message.content,
      sequence: message.sequence,
      source: message.source,
      run_id: message.run_id,
      inserted_at: message.inserted_at
    }
  end

  defp schedule_data(%AgentSchedule{} = schedule) do
    %{
      id: schedule.id,
      cron: schedule.cron,
      message: schedule.message,
      enabled: schedule.enabled,
      last_run_at: schedule.last_run_at,
      inserted_at: schedule.inserted_at,
      updated_at: schedule.updated_at
    }
  end

  defp goal_data(%AgentGoal{} = goal) do
    steps =
      case goal.steps do
        %Ecto.Association.NotLoaded{} -> []
        steps -> Enum.map(steps, &goal_step_data/1)
      end

    %{
      id: goal.id,
      title: goal.title,
      description: goal.description,
      status: goal.status,
      priority: goal.priority,
      due_date: goal.due_date,
      review_schedule_id: goal.review_schedule_id,
      completed_at: goal.completed_at,
      steps: steps,
      inserted_at: goal.inserted_at,
      updated_at: goal.updated_at
    }
  end

  defp goal_step_data(%AgentGoalStep{} = step) do
    %{
      id: step.id,
      title: step.title,
      description: step.description,
      status: step.status,
      position: step.position,
      schedule_id: step.schedule_id,
      result_notes: step.result_notes,
      completed_at: step.completed_at
    }
  end

  defp last_run_data(%{id: nil}), do: nil
  defp last_run_data(%{id: _} = run) do
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
end
