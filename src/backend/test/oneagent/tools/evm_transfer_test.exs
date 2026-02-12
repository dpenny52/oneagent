defmodule OneAgent.Tools.EvmTransferTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools.EvmTransfer

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    context = %{agent: agent}
    %{agent: agent, context: context}
  end

  describe "metadata" do
    test "id is evm_transfer" do
      assert EvmTransfer.id() == "evm_transfer"
    end

    test "bucket is :evm" do
      assert EvmTransfer.bucket() == :evm
    end

    test "required_credential_type is :custom" do
      assert EvmTransfer.required_credential_type() == :custom
    end
  end

  describe "execute/2 input validation" do
    test "rejects unknown action", %{context: context} do
      input = %{"action" => "invalid", "chain" => "ethereum", "to" => "0x0000000000000000000000000000000000000001", "amount" => "1.0"}
      assert {:error, msg} = EvmTransfer.execute(input, context)
      assert msg =~ "Unknown action"
    end

    test "rejects missing chain", %{context: context} do
      input = %{"action" => "send_native", "to" => "0x0000000000000000000000000000000000000001", "amount" => "1.0"}
      assert {:error, msg} = EvmTransfer.execute(input, context)
      assert msg =~ "Missing required parameter: chain"
    end

    test "rejects unknown chain", %{context: context} do
      input = %{"action" => "send_native", "chain" => "solana", "to" => "0x0000000000000000000000000000000000000001", "amount" => "1.0"}
      assert {:error, msg} = EvmTransfer.execute(input, context)
      assert msg =~ "Unknown chain"
    end

    test "rejects missing to address", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"private_key" => "0xabc"}))
      input = %{"action" => "send_native", "chain" => "ethereum", "amount" => "1.0"}
      assert {:error, msg} = EvmTransfer.execute(input, ctx)
      assert msg =~ "Missing required parameter: to"
    end

    test "rejects invalid to address", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"private_key" => "0xabc"}))
      input = %{"action" => "send_native", "chain" => "ethereum", "to" => "invalid", "amount" => "1.0"}
      assert {:error, msg} = EvmTransfer.execute(input, ctx)
      assert msg =~ "Invalid address"
    end

    test "rejects missing amount", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"private_key" => "0xabc"}))
      input = %{"action" => "send_native", "chain" => "ethereum", "to" => "0x0000000000000000000000000000000000000001"}
      assert {:error, msg} = EvmTransfer.execute(input, ctx)
      assert msg =~ "Missing required parameter: amount"
    end

    test "rejects zero amount", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"private_key" => "0xabc"}))
      input = %{"action" => "send_native", "chain" => "ethereum", "to" => "0x0000000000000000000000000000000000000001", "amount" => "0"}
      assert {:error, msg} = EvmTransfer.execute(input, ctx)
      assert msg =~ "Amount must be positive"
    end

    test "rejects negative amount", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"private_key" => "0xabc"}))
      input = %{"action" => "send_native", "chain" => "ethereum", "to" => "0x0000000000000000000000000000000000000001", "amount" => "-1"}
      assert {:error, msg} = EvmTransfer.execute(input, ctx)
      assert msg =~ "Amount must be positive"
    end

    test "rejects send_native with no credential", %{context: context} do
      input = %{"action" => "send_native", "chain" => "ethereum", "to" => "0x0000000000000000000000000000000000000001", "amount" => "1.0"}
      assert {:error, msg} = EvmTransfer.execute(input, context)
      assert msg =~ "No EVM credential"
    end

    test "rejects send_native with invalid credential JSON", %{context: context} do
      ctx = Map.put(context, :credential_value, "not json")
      input = %{"action" => "send_native", "chain" => "ethereum", "to" => "0x0000000000000000000000000000000000000001", "amount" => "1.0"}
      assert {:error, msg} = EvmTransfer.execute(input, ctx)
      assert msg =~ "Invalid credential JSON"
    end

    test "rejects send_token with missing token param", %{context: context} do
      ctx = Map.put(context, :credential_value, Jason.encode!(%{"private_key" => "0xabc"}))
      input = %{"action" => "send_token", "chain" => "ethereum", "to" => "0x0000000000000000000000000000000000000001", "amount" => "1.0"}
      assert {:error, msg} = EvmTransfer.execute(input, ctx)
      assert msg =~ "Missing required parameter: token"
    end
  end
end
