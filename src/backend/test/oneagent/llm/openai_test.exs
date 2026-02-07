defmodule OneAgent.LLM.OpenAITest do
  use ExUnit.Case, async: true

  alias OneAgent.LLM.OpenAI

  # We test parse_response/parse_content indirectly by calling chat/4
  # with a mocked HTTP response. Since parse_content is private,
  # we test it through the public interface using Req.Test.

  describe "response parsing with malformed tool arguments" do
    test "handles valid JSON tool arguments" do
      response = build_tool_response(~s({"key": "value"}))

      Req.Test.stub(OpenAI, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = OpenAI.chat("test-key", "gpt-4o", [user_msg("hello")], req_opts())

      assert [%{type: :tool_use, input: %{"key" => "value"}}] = result.content
    end

    test "gracefully handles malformed JSON tool arguments instead of crashing" do
      response = build_tool_response("not valid json {{{")

      Req.Test.stub(OpenAI, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = OpenAI.chat("test-key", "gpt-4o", [user_msg("hello")], req_opts())

      assert [%{type: :tool_use, input: input}] = result.content
      assert input["_parse_error"] == true
      assert input["_raw"] == "not valid json {{{"
    end

    test "gracefully handles empty string tool arguments" do
      response = build_tool_response("")

      Req.Test.stub(OpenAI, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = OpenAI.chat("test-key", "gpt-4o", [user_msg("hello")], req_opts())

      assert [%{type: :tool_use, input: input}] = result.content
      assert input["_parse_error"] == true
    end

    test "handles nil tool arguments as empty object" do
      response = build_tool_response(nil)

      Req.Test.stub(OpenAI, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = OpenAI.chat("test-key", "gpt-4o", [user_msg("hello")], req_opts())

      assert [%{type: :tool_use, input: %{}}] = result.content
    end
  end

  describe "response parsing structure" do
    test "parses text-only response" do
      response = %{
        "choices" => [
          %{
            "message" => %{"role" => "assistant", "content" => "Hello!"},
            "finish_reason" => "stop"
          }
        ],
        "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 5}
      }

      Req.Test.stub(OpenAI, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = OpenAI.chat("test-key", "gpt-4o", [user_msg("hi")], req_opts())

      assert [%{type: :text, text: "Hello!"}] = result.content
      assert result.usage == %{input_tokens: 10, output_tokens: 5}
      assert result.stop_reason == "end_turn"
    end

    test "maps tool_calls finish_reason to tool_use" do
      response = build_tool_response(~s({"query": "test"}))

      Req.Test.stub(OpenAI, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = OpenAI.chat("test-key", "gpt-4o", [user_msg("search")], req_opts())

      assert result.stop_reason == "tool_use"
    end

    test "handles empty choices gracefully" do
      response = %{"choices" => [], "usage" => %{}}

      Req.Test.stub(OpenAI, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = OpenAI.chat("test-key", "gpt-4o", [user_msg("hi")], req_opts())

      assert result.content == []
      assert result.usage == %{input_tokens: 0, output_tokens: 0}
    end
  end

  describe "error handling" do
    test "returns error for non-200 responses" do
      Req.Test.stub(OpenAI, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, "OpenAI API error: Rate limit exceeded"} =
               OpenAI.chat("test-key", "gpt-4o", [user_msg("hi")], req_opts())
    end
  end

  # Helpers

  defp user_msg(text), do: %{"role" => "user", "content" => text}

  defp req_opts, do: [plug: {Req.Test, OpenAI}]

  defp build_tool_response(arguments) do
    tool_call = %{
      "id" => "call_abc123",
      "type" => "function",
      "function" => %{
        "name" => "http_request",
        "arguments" => arguments
      }
    }

    %{
      "choices" => [
        %{
          "message" => %{
            "role" => "assistant",
            "content" => nil,
            "tool_calls" => [tool_call]
          },
          "finish_reason" => "tool_calls"
        }
      ],
      "usage" => %{"prompt_tokens" => 20, "completion_tokens" => 15}
    }
  end
end
