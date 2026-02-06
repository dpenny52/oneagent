defmodule OneAgent.Tools.Tool do
  @moduledoc """
  Behaviour for agent tools. Each tool declares its identity,
  which permission bucket it belongs to, its JSON Schema for
  LLM tool_use, and an execute callback.
  """

  @callback id() :: String.t()
  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback bucket() :: atom() | nil
  @callback parameters_schema() :: map()
  @callback required_credential_type() :: atom() | nil
  @callback execute(input :: map(), context :: map()) :: {:ok, map()} | {:error, String.t()}
end
