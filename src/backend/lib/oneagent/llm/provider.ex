defmodule OneAgent.LLM.Provider do
  @moduledoc """
  Behaviour for LLM providers (Anthropic, OpenAI).
  """

  @type message :: %{String.t() => term()}
  @type tool_def :: %{String.t() => term()}

  @type response :: %{
    content: [content_block()],
    usage: %{input_tokens: integer(), output_tokens: integer()},
    stop_reason: String.t()
  }

  @type content_block ::
    %{type: :text, text: String.t()} |
    %{type: :tool_use, id: String.t(), name: String.t(), input: map()}

  @callback chat(
    api_key :: String.t(),
    model :: String.t(),
    messages :: [message()],
    opts :: keyword()
  ) :: {:ok, response()} | {:error, term()}
end
