defmodule OneAgent.LLM do
  @moduledoc """
  LLM client layer. Dispatches to the correct provider based on
  the agent's configuration.
  """

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
      nil -> {:error, "Unknown LLM provider: #{provider_name}"}
      mod -> mod.chat(api_key, model, messages, opts)
    end
  end
end
