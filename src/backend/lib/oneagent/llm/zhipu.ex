defmodule OneAgent.LLM.Zhipu do
  @moduledoc """
  Zhipu (Z.AI) GLM provider implementation.

  Delegates to the OpenAI module since the Z.AI API is OpenAI-compatible,
  only overriding the base URL and error prefix.

  GLM-5 has a strict concurrency limit (1 concurrent request), so on rate
  limit errors the module automatically falls back to GLM-4.7.
  """

  @behaviour OneAgent.LLM.Provider
  require Logger

  @api_url "https://api.z.ai/api/paas/v4/chat/completions"

  @fallback_models %{
    "glm-5" => "glm-4.7"
  }

  @impl true
  def chat(api_key, model, messages, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:base_url, @api_url)
      |> Keyword.put_new(:error_prefix, "Zhipu")

    case OneAgent.LLM.OpenAI.chat(api_key, model, messages, opts) do
      {:ok, _} = success ->
        success

      {:error, msg} = error when is_binary(msg) ->
        fallback = Map.get(@fallback_models, model)

        if fallback && rate_limited?(msg) do
          Logger.warning("Zhipu rate limited on #{model}, falling back to #{fallback}")
          OneAgent.LLM.OpenAI.chat(api_key, fallback, messages, opts)
        else
          error
        end
    end
  end

  defp rate_limited?(msg) do
    downcased = String.downcase(msg)
    String.contains?(downcased, "429") or String.contains?(downcased, "rate limit")
  end
end
