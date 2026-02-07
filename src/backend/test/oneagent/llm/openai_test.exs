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

  describe "message conversion for agentic loop" do
    test "converts Anthropic-style tool_result blocks to OpenAI tool role messages" do
      # This is the format agent_process.ex produces after tool execution
      messages = [
        %{"role" => "user", "content" => "search for cats"},
        %{"role" => "assistant", "content" => [
          %{"type" => "tool_use", "id" => "call_1", "name" => "http_request", "input" => %{"url" => "https://example.com"}}
        ]},
        %{"role" => "user", "content" => [
          %{"type" => "tool_result", "tool_use_id" => "call_1", "content" => ~s({"status": 200})}
        ]}
      ]

      Req.Test.stub(OpenAI, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        sent = Jason.decode!(body)

        # Verify tool results converted to "tool" role messages
        tool_msgs = Enum.filter(sent["messages"], &(&1["role"] == "tool"))
        assert length(tool_msgs) == 1
        [tool_msg] = tool_msgs
        assert tool_msg["tool_call_id"] == "call_1"
        assert tool_msg["content"] == ~s({"status": 200})

        # Verify assistant message has tool_calls
        assistant_msgs = Enum.filter(sent["messages"], &(&1["role"] == "assistant"))
        assert length(assistant_msgs) == 1
        [assistant_msg] = assistant_msgs
        assert [%{"id" => "call_1", "type" => "function"}] = assistant_msg["tool_calls"]

        Req.Test.json(conn, text_response("Done!"))
      end)

      {:ok, result} = OpenAI.chat("test-key", "gpt-4o", messages, req_opts())
      assert [%{type: :text, text: "Done!"}] = result.content
    end

    test "converts multiple tool results to separate tool role messages" do
      messages = [
        %{"role" => "user", "content" => "do two things"},
        %{"role" => "assistant", "content" => [
          %{"type" => "tool_use", "id" => "call_a", "name" => "http_request", "input" => %{}},
          %{"type" => "tool_use", "id" => "call_b", "name" => "read_webpage", "input" => %{}}
        ]},
        %{"role" => "user", "content" => [
          %{"type" => "tool_result", "tool_use_id" => "call_a", "content" => "result_a"},
          %{"type" => "tool_result", "tool_use_id" => "call_b", "content" => "result_b"}
        ]}
      ]

      Req.Test.stub(OpenAI, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        sent = Jason.decode!(body)

        tool_msgs = Enum.filter(sent["messages"], &(&1["role"] == "tool"))
        assert length(tool_msgs) == 2
        ids = Enum.map(tool_msgs, & &1["tool_call_id"])
        assert "call_a" in ids
        assert "call_b" in ids

        Req.Test.json(conn, text_response("Both done"))
      end)

      {:ok, _result} = OpenAI.chat("test-key", "gpt-4o", messages, req_opts())
    end

    test "handles assistant tool_use blocks with atom keys (from parse_content)" do
      # This is the format returned by OpenAI's own parse_content (atom keys)
      messages = [
        %{"role" => "user", "content" => "hello"},
        %{"role" => "assistant", "content" => [
          %{type: :text, text: "Let me check"},
          %{type: :tool_use, id: "call_x", name: "http_request", input: %{"url" => "https://example.com"}}
        ]}
      ]

      Req.Test.stub(OpenAI, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        sent = Jason.decode!(body)

        assistant_msgs = Enum.filter(sent["messages"], &(&1["role"] == "assistant"))
        [assistant_msg] = assistant_msgs
        assert assistant_msg["content"] == "Let me check"
        assert [%{"id" => "call_x", "type" => "function"}] = assistant_msg["tool_calls"]

        Req.Test.json(conn, text_response("OK"))
      end)

      {:ok, _result} = OpenAI.chat("test-key", "gpt-4o", messages, req_opts())
    end

    test "preserves plain text user messages unchanged" do
      messages = [%{"role" => "user", "content" => "just text"}]

      Req.Test.stub(OpenAI, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        sent = Jason.decode!(body)

        user_msgs = Enum.filter(sent["messages"], &(&1["role"] == "user"))
        assert [%{"content" => "just text"}] = user_msgs

        Req.Test.json(conn, text_response("Hi"))
      end)

      {:ok, _result} = OpenAI.chat("test-key", "gpt-4o", messages, req_opts())
    end

    test "converts user message with Anthropic-style text content blocks" do
      messages = [
        %{"role" => "user", "content" => [
          %{"type" => "text", "text" => "line one"},
          %{"type" => "text", "text" => "line two"}
        ]}
      ]

      Req.Test.stub(OpenAI, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        sent = Jason.decode!(body)

        user_msgs = Enum.filter(sent["messages"], &(&1["role"] == "user"))
        assert [%{"content" => "line one\nline two"}] = user_msgs

        Req.Test.json(conn, text_response("Got it"))
      end)

      {:ok, _result} = OpenAI.chat("test-key", "gpt-4o", messages, req_opts())
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

  defp text_response(text) do
    %{
      "choices" => [
        %{
          "message" => %{"role" => "assistant", "content" => text},
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 5}
    }
  end

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
