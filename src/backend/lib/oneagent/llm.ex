defmodule OneAgent.LLM do
  @moduledoc """
  LLM client layer. Dispatches to the correct provider based on
  the agent's configuration.
  """

  require Logger

  alias OneAgent.LLM.{Anthropic, OpenAI, Zhipu}

  @providers %{
    "anthropic" => Anthropic,
    "openai" => OpenAI,
    "zhipu" => Zhipu
  }

  def provider_module(provider_name) do
    Map.get(@providers, provider_name)
  end

  def chat(provider_name, api_key, model, messages, opts \\ []) do
    case provider_module(provider_name) do
      nil ->
        {:error, "Unknown LLM provider: #{provider_name}"}

      mod ->
        msg_count = length(messages)
        tool_count = opts |> Keyword.get(:tools, []) |> length()
        timeout = Keyword.get(opts, :receive_timeout, 120_000)

        Logger.info("LLM request: provider=#{provider_name} model=#{model} messages=#{msg_count} tools=#{tool_count} timeout=#{timeout}ms")

        start = System.monotonic_time(:millisecond)
        result = mod.chat(api_key, model, messages, opts)
        elapsed = System.monotonic_time(:millisecond) - start

        case result do
          {:ok, response} ->
            in_tok = response.usage.input_tokens
            out_tok = response.usage.output_tokens
            stop = response.stop_reason
            blocks = length(response.content)

            Logger.info("LLM response: provider=#{provider_name} model=#{model} status=ok stop_reason=#{stop} in_tokens=#{in_tok} out_tokens=#{out_tok} blocks=#{blocks} elapsed=#{elapsed}ms")

          {:error, reason} ->
            Logger.error("LLM error: provider=#{provider_name} model=#{model} elapsed=#{elapsed}ms error=#{inspect(reason)}")
        end

        result
    end
  end
end
