defmodule OneAgent.Runtime.AgentSupervisor do
  @moduledoc """
  DynamicSupervisor for agent processes. Each running agent gets
  a GenServer child process.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_agent(agent) do
    spec = {OneAgent.Runtime.AgentProcess, agent}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_agent(agent_id) do
    case Registry.lookup(OneAgent.Runtime.AgentRegistry, agent_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        {:error, :not_running}
    end
  end
end
