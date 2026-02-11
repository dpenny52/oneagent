defmodule OneAgent.Tools.SendTelegramTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools.SendTelegram

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    context = %{agent: agent}
    %{agent: agent, context: context}
  end

  describe "metadata" do
    test "id is send_telegram" do
      assert SendTelegram.id() == "send_telegram"
    end

    test "bucket is :telegram" do
      assert SendTelegram.bucket() == :telegram
    end

    test "required_credential_type is :api_key" do
      assert SendTelegram.required_credential_type() == :api_key
    end
  end

  describe "execute/2 input validation" do
    test "rejects missing chat_id parameter", %{context: context} do
      assert {:error, msg} = SendTelegram.execute(%{"message" => "Hello"}, context)
      assert msg =~ "Missing required parameter: chat_id"
    end

    test "rejects empty chat_id parameter", %{context: context} do
      assert {:error, msg} =
               SendTelegram.execute(%{"chat_id" => "", "message" => "Hello"}, context)

      assert msg =~ "Missing required parameter: chat_id"
    end

    test "rejects nil chat_id parameter", %{context: context} do
      assert {:error, msg} =
               SendTelegram.execute(%{"chat_id" => nil, "message" => "Hello"}, context)

      assert msg =~ "Missing required parameter: chat_id"
    end

    test "rejects whitespace-only chat_id", %{context: context} do
      assert {:error, msg} =
               SendTelegram.execute(%{"chat_id" => "   ", "message" => "Hello"}, context)

      assert msg =~ "Missing required parameter: chat_id"
    end

    test "rejects missing message parameter", %{context: context} do
      assert {:error, msg} = SendTelegram.execute(%{"chat_id" => "12345"}, context)
      assert msg =~ "Missing required parameter: message"
    end

    test "rejects empty message", %{context: context} do
      assert {:error, msg} =
               SendTelegram.execute(%{"chat_id" => "12345", "message" => ""}, context)

      assert msg =~ "Missing required parameter: message"
    end

    test "rejects whitespace-only message", %{context: context} do
      assert {:error, msg} =
               SendTelegram.execute(%{"chat_id" => "12345", "message" => "   \n  "}, context)

      assert msg =~ "Missing required parameter: message"
    end

    test "rejects nil message", %{context: context} do
      assert {:error, msg} =
               SendTelegram.execute(%{"chat_id" => "12345", "message" => nil}, context)

      assert msg =~ "Missing required parameter: message"
    end

    test "rejects message exceeding 4096 characters", %{context: context} do
      long_message = String.duplicate("a", 4097)

      assert {:error, msg} =
               SendTelegram.execute(%{"chat_id" => "12345", "message" => long_message}, context)

      assert msg =~ "Message too long"
    end
  end

  describe "execute/2 credential validation" do
    test "returns error when no credential configured", %{context: context} do
      # Context has no credential_value
      assert {:error, msg} =
               SendTelegram.execute(%{"chat_id" => "12345", "message" => "Hello"}, context)

      assert msg =~ "No Telegram credential configured"
    end

    test "returns error when no active channel for agent", %{context: context} do
      # Has valid credential but no Telegram channel configured
      context = Map.put(context, :credential_value, "123456:AAF_valid_bot_token")

      assert {:error, msg} =
               SendTelegram.execute(%{"chat_id" => "12345", "message" => "Hello"}, context)

      assert msg =~ "No active Telegram channel"
    end
  end
end
