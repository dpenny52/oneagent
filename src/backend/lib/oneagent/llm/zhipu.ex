defmodule OneAgent.LLM.Zhipu do
  @moduledoc """
  Zhipu (Z.AI) GLM provider implementation.

  Delegates to the OpenAI module since the Z.AI API is OpenAI-compatible,
  only overriding the base URL and error prefix.
  """

  @behaviour OneAgent.LLM.Provider

  @api_url "https://api.z.ai/api/paas/v4/chat/completions"

  @impl true
  def chat(api_key, model, messages, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:base_url, @api_url)
      |> Keyword.put_new(:error_prefix, "Zhipu")

    OneAgent.LLM.OpenAI.chat(api_key, model, messages, opts)
  end
end
