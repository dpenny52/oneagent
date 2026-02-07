defmodule OneAgent.LLM.AnthropicTest do
  use ExUnit.Case, async: true

  alias OneAgent.LLM.Anthropic

  describe "response parsing structure" do
    test "parses text-only response" do
      response = %{
        "content" => [%{"type" => "text", "text" => "Hello!"}],
        "usage" => %{"input_tokens" => 10, "output_tokens" => 5},
        "stop_reason" => "end_turn"
      }

      Req.Test.stub(Anthropic, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = Anthropic.chat("test-key", "claude-sonnet-4-20250514", [user_msg("hi")], req_opts())

      assert [%{type: :text, text: "Hello!"}] = result.content
      assert result.usage == %{input_tokens: 10, output_tokens: 5}
      assert result.stop_reason == "end_turn"
    end

    test "parses tool_use response" do
      response = %{
        "content" => [
          %{"type" => "tool_use", "id" => "toolu_1", "name" => "http_request", "input" => %{"url" => "https://example.com"}}
        ],
        "usage" => %{"input_tokens" => 20, "output_tokens" => 15},
        "stop_reason" => "tool_use"
      }

      Req.Test.stub(Anthropic, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = Anthropic.chat("test-key", "claude-sonnet-4-20250514", [user_msg("search")], req_opts())

      assert [%{type: :tool_use, id: "toolu_1", name: "http_request", input: %{"url" => "https://example.com"}}] = result.content
      assert result.stop_reason == "tool_use"
    end

    test "parses mixed text and tool_use response" do
      response = %{
        "content" => [
          %{"type" => "text", "text" => "Let me look that up."},
          %{"type" => "tool_use", "id" => "toolu_2", "name" => "read_webpage", "input" => %{"url" => "https://example.com"}}
        ],
        "usage" => %{"input_tokens" => 25, "output_tokens" => 20},
        "stop_reason" => "tool_use"
      }

      Req.Test.stub(Anthropic, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = Anthropic.chat("test-key", "claude-sonnet-4-20250514", [user_msg("check this")], req_opts())

      assert [
        %{type: :text, text: "Let me look that up."},
        %{type: :tool_use, id: "toolu_2", name: "read_webpage"}
      ] = result.content
    end
  end

  describe "defensive response parsing" do
    test "handles nil content gracefully" do
      response = %{
        "content" => nil,
        "usage" => %{"input_tokens" => 5, "output_tokens" => 0},
        "stop_reason" => "end_turn"
      }

      Req.Test.stub(Anthropic, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = Anthropic.chat("test-key", "claude-sonnet-4-20250514", [user_msg("hi")], req_opts())

      assert result.content == []
      assert result.usage == %{input_tokens: 5, output_tokens: 0}
    end

    test "handles missing content key gracefully" do
      response = %{
        "usage" => %{"input_tokens" => 5, "output_tokens" => 0},
        "stop_reason" => "end_turn"
      }

      Req.Test.stub(Anthropic, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = Anthropic.chat("test-key", "claude-sonnet-4-20250514", [user_msg("hi")], req_opts())

      assert result.content == []
    end

    test "skips unrecognized content block types" do
      response = %{
        "content" => [
          %{"type" => "text", "text" => "Here you go."},
          %{"type" => "thinking", "thinking" => "Let me reason about this..."},
          %{"type" => "image", "source" => %{"data" => "base64..."}}
        ],
        "usage" => %{"input_tokens" => 10, "output_tokens" => 5},
        "stop_reason" => "end_turn"
      }

      Req.Test.stub(Anthropic, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = Anthropic.chat("test-key", "claude-sonnet-4-20250514", [user_msg("hi")], req_opts())

      assert [%{type: :text, text: "Here you go."}] = result.content
    end

    test "handles missing usage gracefully" do
      response = %{
        "content" => [%{"type" => "text", "text" => "Hi"}],
        "stop_reason" => "end_turn"
      }

      Req.Test.stub(Anthropic, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = Anthropic.chat("test-key", "claude-sonnet-4-20250514", [user_msg("hi")], req_opts())

      assert result.usage == %{input_tokens: 0, output_tokens: 0}
    end

    test "handles empty content array" do
      response = %{
        "content" => [],
        "usage" => %{"input_tokens" => 5, "output_tokens" => 0},
        "stop_reason" => "end_turn"
      }

      Req.Test.stub(Anthropic, fn conn ->
        Req.Test.json(conn, response)
      end)

      {:ok, result} = Anthropic.chat("test-key", "claude-sonnet-4-20250514", [user_msg("hi")], req_opts())

      assert result.content == []
    end
  end

  describe "error handling" do
    test "returns error for non-200 responses" do
      Req.Test.stub(Anthropic, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, "Anthropic API error: Rate limit exceeded"} =
               Anthropic.chat("test-key", "claude-sonnet-4-20250514", [user_msg("hi")], req_opts())
    end

    test "returns error for non-200 without error message" do
      Req.Test.stub(Anthropic, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{})
      end)

      assert {:error, "Anthropic API error: HTTP 500"} =
               Anthropic.chat("test-key", "claude-sonnet-4-20250514", [user_msg("hi")], req_opts())
    end
  end

  # Helpers

  defp user_msg(text), do: %{"role" => "user", "content" => text}

  defp req_opts, do: [plug: {Req.Test, Anthropic}]
end
