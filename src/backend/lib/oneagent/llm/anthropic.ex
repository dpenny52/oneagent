defmodule OneAgent.LLM.Anthropic do
  @moduledoc """
  Anthropic Messages API provider implementation.
  """

  @behaviour OneAgent.LLM.Provider

  @api_url "https://api.anthropic.com/v1/messages"
  @api_version "2023-06-01"

  @impl true
  def chat(api_key, model, messages, opts \\ []) do
    system = Keyword.get(opts, :system)
    tools = Keyword.get(opts, :tools, [])
    max_tokens = Keyword.get(opts, :max_tokens, 4096)

    body =
      %{
        model: model,
        messages: messages,
        max_tokens: max_tokens
      }
      |> maybe_put(:system, system)
      |> maybe_put_tools(tools)

    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", @api_version},
      {"content-type", "application/json"}
    ]

    req_opts = Keyword.get(opts, :plug)
    extra = if req_opts, do: [plug: req_opts], else: []

    case Req.post(@api_url, [json: body, headers: headers, receive_timeout: 120_000, retry: :transient, max_retries: 3] ++ extra) do
      {:ok, %Req.Response{status: 200, body: resp}} ->
        {:ok, parse_response(resp)}

      {:ok, %Req.Response{status: status, body: resp}} ->
        error_msg = get_in(resp, ["error", "message"]) || "HTTP #{status}"
        {:error, "Anthropic API error: #{error_msg}"}

      {:error, reason} ->
        {:error, "Anthropic API request failed: #{inspect(reason)}"}
    end
  end

  defp parse_response(resp) do
    content =
      (resp["content"] || [])
      |> Enum.flat_map(fn
        %{"type" => "text", "text" => text} ->
          [%{type: :text, text: text}]

        %{"type" => "tool_use", "id" => id, "name" => name, "input" => input} ->
          [%{type: :tool_use, id: id, name: name, input: input}]

        _unrecognized ->
          []
      end)

    usage = %{
      input_tokens: get_in(resp, ["usage", "input_tokens"]) || 0,
      output_tokens: get_in(resp, ["usage", "output_tokens"]) || 0
    }

    %{
      content: content,
      usage: usage,
      stop_reason: resp["stop_reason"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_tools(map, []), do: map
  defp maybe_put_tools(map, tools), do: Map.put(map, :tools, tools)
end
