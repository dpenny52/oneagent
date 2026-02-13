defmodule OneAgent.LLM.OpenAI do
  @moduledoc """
  OpenAI Chat Completions API provider implementation.
  """

  @behaviour OneAgent.LLM.Provider

  @api_url "https://api.openai.com/v1/chat/completions"

  @impl true
  def chat(api_key, model, messages, opts \\ []) do
    system = Keyword.get(opts, :system)
    tools = Keyword.get(opts, :tools, [])
    max_tokens = Keyword.get(opts, :max_tokens, 4096)

    messages = maybe_prepend_system(messages, system)

    body =
      %{
        model: model,
        messages: convert_messages(messages),
        max_tokens: max_tokens
      }
      |> maybe_put_tools(tools)

    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]

    recv_timeout = Keyword.get(opts, :receive_timeout, 120_000)
    max_retries = Keyword.get(opts, :max_retries, 3)

    req_opts = Keyword.get(opts, :plug)
    extra = if req_opts, do: [plug: req_opts], else: []

    url = Keyword.get(opts, :base_url, @api_url)
    error_prefix = Keyword.get(opts, :error_prefix, "OpenAI")

    case Req.post(url, [json: body, headers: headers, receive_timeout: recv_timeout, connect_options: [timeout: 30_000], retry: :transient, max_retries: max_retries] ++ extra) do
      {:ok, %Req.Response{status: 200, body: resp}} ->
        {:ok, parse_response(resp)}

      {:ok, %Req.Response{status: status, body: resp}} ->
        error_msg = get_in(resp, ["error", "message"]) || "HTTP #{status}"
        {:error, "#{error_prefix} API error: #{error_msg}"}

      {:error, reason} ->
        {:error, "#{error_prefix} API request failed: #{inspect(reason)}"}
    end
  end

  defp maybe_prepend_system(messages, nil), do: messages
  defp maybe_prepend_system(messages, system) do
    [%{"role" => "system", "content" => system} | messages]
  end

  defp convert_messages(messages) do
    Enum.flat_map(messages, fn msg ->
      case msg do
        %{"role" => "user", "content" => content} when is_list(content) ->
          tool_results = Enum.filter(content, &(is_map(&1) && &1["type"] == "tool_result"))
          text_blocks = Enum.filter(content, &(is_map(&1) && &1["type"] == "text"))

          if tool_results != [] do
            # Convert Anthropic-style tool_result blocks to OpenAI "tool" role messages
            Enum.map(tool_results, fn tr ->
              %{
                "role" => "tool",
                "tool_call_id" => tr["tool_use_id"],
                "content" => tr["content"] || ""
              }
            end)
          else
            text = text_blocks |> Enum.map(& &1["text"]) |> Enum.join("\n")
            [%{"role" => "user", "content" => text}]
          end

        %{"role" => "assistant", "content" => content} when is_list(content) ->
          # Convert tool_use blocks to OpenAI format (support both atom and string keys)
          tool_calls = content
            |> Enum.filter(fn item ->
              is_map(item) && (item[:type] == :tool_use || item["type"] == "tool_use")
            end)
            |> Enum.map(fn tc ->
              %{
                "id" => tc[:id] || tc["id"],
                "type" => "function",
                "function" => %{
                  "name" => tc[:name] || tc["name"],
                  "arguments" => Jason.encode!(tc[:input] || tc["input"])
                }
              }
            end)

          text = content
            |> Enum.filter(fn item ->
              is_map(item) && (item[:type] == :text || item["type"] == "text")
            end)
            |> Enum.map(&(&1[:text] || &1["text"]))
            |> Enum.join("\n")

          base = %{"role" => "assistant", "content" => text}
          [if(tool_calls != [], do: Map.put(base, "tool_calls", tool_calls), else: base)]

        other -> [other]
      end
    end)
  end

  defp parse_response(resp) do
    choice = List.first(resp["choices"] || []) || %{}
    message = choice["message"] || %{}

    content = parse_content(message)

    usage = %{
      input_tokens: get_in(resp, ["usage", "prompt_tokens"]) || 0,
      output_tokens: get_in(resp, ["usage", "completion_tokens"]) || 0
    }

    stop_reason = case choice["finish_reason"] do
      "stop" -> "end_turn"
      "tool_calls" -> "tool_use"
      other -> other
    end

    %{content: content, usage: usage, stop_reason: stop_reason}
  end

  defp parse_content(message) do
    text_blocks =
      case message["content"] do
        nil -> []
        "" -> []
        text -> [%{type: :text, text: text}]
      end

    tool_blocks =
      (message["tool_calls"] || [])
      |> Enum.map(fn tc ->
        args = get_in(tc, ["function", "arguments"]) || "{}"

        input =
          case Jason.decode(args) do
            {:ok, parsed} -> parsed
            {:error, _} -> %{"_raw" => args, "_parse_error" => true}
          end

        %{
          type: :tool_use,
          id: tc["id"],
          name: get_in(tc, ["function", "name"]),
          input: input
        }
      end)

    text_blocks ++ tool_blocks
  end

  defp maybe_put_tools(body, []), do: body
  defp maybe_put_tools(body, tools) do
    openai_tools = Enum.map(tools, fn tool ->
      %{
        "type" => "function",
        "function" => %{
          "name" => tool["name"],
          "description" => tool["description"],
          "parameters" => tool["input_schema"]
        }
      }
    end)
    Map.put(body, :tools, openai_tools)
  end
end
