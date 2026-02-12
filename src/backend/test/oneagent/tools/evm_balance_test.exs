defmodule OneAgent.Tools.EvmBalanceTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools.EvmBalance

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    context = %{agent: agent}
    %{agent: agent, context: context}
  end

  describe "metadata" do
    test "id is evm_balance" do
      assert EvmBalance.id() == "evm_balance"
    end

    test "bucket is :evm" do
      assert EvmBalance.bucket() == :evm
    end

    test "required_credential_type is nil" do
      assert EvmBalance.required_credential_type() == nil
    end
  end

  describe "execute/2 input validation" do
    test "rejects unknown action", %{context: context} do
      assert {:error, msg} = EvmBalance.execute(%{"action" => "invalid", "chain" => "ethereum"}, context)
      assert msg =~ "Unknown action"
    end

    test "rejects missing chain", %{context: context} do
      assert {:error, msg} = EvmBalance.execute(%{"action" => "native"}, context)
      assert msg =~ "Missing required parameter: chain"
    end

    test "rejects unknown chain", %{context: context} do
      assert {:error, msg} = EvmBalance.execute(%{"action" => "native", "chain" => "solana"}, context)
      assert msg =~ "Unknown chain"
    end

    test "rejects invalid address format", %{context: context} do
      assert {:error, msg} = EvmBalance.execute(%{"action" => "native", "chain" => "ethereum", "address" => "invalid"}, context)
      assert msg =~ "Invalid address"
    end

    test "rejects native without address or credential", %{context: context} do
      assert {:error, msg} = EvmBalance.execute(%{"action" => "native", "chain" => "ethereum"}, context)
      assert msg =~ "No address provided"
    end

    test "rejects token action without token param", %{context: context} do
      input = %{"action" => "token", "chain" => "ethereum", "address" => "0x0000000000000000000000000000000000000001"}
      assert {:error, msg} = EvmBalance.execute(input, context)
      assert msg =~ "Missing required parameter: token"
    end

    test "rejects multi action without tokens param", %{context: context} do
      input = %{"action" => "multi", "chain" => "ethereum", "address" => "0x0000000000000000000000000000000000000001"}
      assert {:error, msg} = EvmBalance.execute(input, context)
      assert msg =~ "Missing required parameter: tokens"
    end
  end
end
