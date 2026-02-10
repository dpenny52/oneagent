defmodule OneAgent.Tools.SendWhatsAppTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools.SendWhatsApp

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    context = %{agent: agent}
    %{agent: agent, context: context}
  end

  describe "metadata" do
    test "id is send_whatsapp" do
      assert SendWhatsApp.id() == "send_whatsapp"
    end

    test "bucket is :whatsapp" do
      assert SendWhatsApp.bucket() == :whatsapp
    end

    test "required_credential_type is :custom" do
      assert SendWhatsApp.required_credential_type() == :custom
    end
  end

  describe "execute/2 input validation" do
    test "rejects missing to parameter", %{context: context} do
      assert {:error, msg} = SendWhatsApp.execute(%{"message" => "Hello"}, context)
      assert msg =~ "Missing required parameter: to"
    end

    test "rejects empty to parameter", %{context: context} do
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "", "message" => "Hello"}, context)
      assert msg =~ "Missing required parameter: to"
    end

    test "rejects nil to parameter", %{context: context} do
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => nil, "message" => "Hello"}, context)
      assert msg =~ "Missing required parameter: to"
    end

    test "rejects phone number with + prefix", %{context: context} do
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "+15551234567", "message" => "Hello"}, context)
      assert msg =~ "Invalid phone number"
    end

    test "rejects phone number with spaces", %{context: context} do
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "1555 123 4567", "message" => "Hello"}, context)
      assert msg =~ "Invalid phone number"
    end

    test "rejects phone number with dashes", %{context: context} do
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "1555-123-4567", "message" => "Hello"}, context)
      assert msg =~ "Invalid phone number"
    end

    test "rejects phone number too short (less than 7 digits)", %{context: context} do
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "123456", "message" => "Hello"}, context)
      assert msg =~ "Invalid phone number"
    end

    test "rejects phone number too long (more than 15 digits)", %{context: context} do
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "1234567890123456", "message" => "Hello"}, context)
      assert msg =~ "Invalid phone number"
    end

    test "rejects non-digit characters in phone number", %{context: context} do
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "155512abc67", "message" => "Hello"}, context)
      assert msg =~ "Invalid phone number"
    end

    test "rejects missing message parameter", %{context: context} do
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "15551234567"}, context)
      assert msg =~ "Missing required parameter: message"
    end

    test "rejects empty message", %{context: context} do
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "15551234567", "message" => ""}, context)
      assert msg =~ "Missing required parameter: message"
    end

    test "rejects whitespace-only message", %{context: context} do
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "15551234567", "message" => "   \n  "}, context)
      assert msg =~ "Missing required parameter: message"
    end

    test "rejects nil message", %{context: context} do
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "15551234567", "message" => nil}, context)
      assert msg =~ "Missing required parameter: message"
    end

    test "rejects message exceeding 4096 characters", %{context: context} do
      long_message = String.duplicate("a", 4097)
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "15551234567", "message" => long_message}, context)
      assert msg =~ "Message too long"
    end
  end

  describe "execute/2 credential validation" do
    test "returns error when no credential configured", %{context: context} do
      # Context has no credential_value
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "15551234567", "message" => "Hello"}, context)
      assert msg =~ "No WhatsApp credential configured"
    end

    test "returns error for invalid credential JSON", %{context: context} do
      context = Map.put(context, :credential_value, "not-valid-json")
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "15551234567", "message" => "Hello"}, context)
      assert msg =~ "Invalid WhatsApp credential format"
    end

    test "returns error when credential missing access_token", %{context: context} do
      context = Map.put(context, :credential_value, Jason.encode!(%{"other_key" => "value"}))
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "15551234567", "message" => "Hello"}, context)
      assert msg =~ "missing access_token"
    end

    test "returns error when access_token is empty string", %{context: context} do
      context = Map.put(context, :credential_value, Jason.encode!(%{"access_token" => ""}))
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "15551234567", "message" => "Hello"}, context)
      assert msg =~ "missing access_token"
    end

    test "returns error when no active channel for agent", %{context: context} do
      # Has valid credential but no WhatsApp channel configured
      context = Map.put(context, :credential_value, Jason.encode!(%{"access_token" => "valid_token"}))
      assert {:error, msg} = SendWhatsApp.execute(%{"to" => "15551234567", "message" => "Hello"}, context)
      assert msg =~ "No active WhatsApp channel"
    end
  end
end
