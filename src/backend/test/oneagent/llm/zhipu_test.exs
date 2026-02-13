defmodule OneAgent.LLM.ZhipuTest do
  use ExUnit.Case, async: true

  alias OneAgent.LLM.Zhipu

  describe "fallback behavior" do
    test "falls back to GLM-4.7 on transport timeout error" do
      call_count = :counters.new(1, [:atomics])

      Req.Test.stub(Zhipu, fn conn ->
        :counters.add(call_count, 1, 1)

        case :counters.get(call_count, 1) do
          1 ->
            # First call (GLM-5) fails with transport error
            Req.Test.transport_error(conn, :timeout)

          2 ->
            # Second call (GLM-4.7 fallback) succeeds
            Req.Test.json(conn, text_response("fallback response"))
        end
      end)

      {:ok, result} = Zhipu.chat("test-key", "glm-5", [user_msg("hello")], req_opts())

      assert [%{type: :text, text: "fallback response"}] = result.content
      assert :counters.get(call_count, 1) == 2
    end

    test "falls back to GLM-4.7 on rate limit error" do
      call_count = :counters.new(1, [:atomics])

      Req.Test.stub(Zhipu, fn conn ->
        :counters.add(call_count, 1, 1)

        case :counters.get(call_count, 1) do
          1 ->
            conn
            |> Plug.Conn.put_status(429)
            |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})

          2 ->
            Req.Test.json(conn, text_response("fallback response"))
        end
      end)

      {:ok, result} = Zhipu.chat("test-key", "glm-5", [user_msg("hello")], req_opts())

      assert [%{type: :text, text: "fallback response"}] = result.content
      assert :counters.get(call_count, 1) == 2
    end

    test "does NOT fall back on auth failure" do
      Req.Test.stub(Zhipu, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid API key"}})
      end)

      assert {:error, "Zhipu API error: Invalid API key"} =
               Zhipu.chat("bad-key", "glm-5", [user_msg("hello")], req_opts())
    end

    test "does NOT fall back for models without a configured fallback" do
      Req.Test.stub(Zhipu, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, msg} = Zhipu.chat("test-key", "glm-4.7", [user_msg("hello")], req_opts())
      assert msg =~ "timeout"
    end
  end

  # Helpers

  defp user_msg(text), do: %{"role" => "user", "content" => text}

  defp req_opts, do: [plug: {Req.Test, Zhipu}, max_retries: 0]

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
end
