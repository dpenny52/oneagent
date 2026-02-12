defmodule OneAgent.Tools.EvmSwapTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools.EvmSwap

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    context = %{agent: agent}
    %{agent: agent, context: context}
  end

  describe "metadata" do
    test "id is evm_swap" do
      assert EvmSwap.id() == "evm_swap"
    end

    test "bucket is :evm" do
      assert EvmSwap.bucket() == :evm
    end

    test "required_credential_type is :custom" do
      assert EvmSwap.required_credential_type() == :custom
    end
  end

  describe "execute/2 input validation" do
    test "rejects unknown action", %{context: context} do
      input = %{"action" => "invalid", "chain" => "ethereum", "sell_token" => "USDC", "buy_token" => "WETH", "sell_amount" => "100"}
      assert {:error, msg} = EvmSwap.execute(input, context)
      assert msg =~ "Unknown action"
    end

    test "rejects missing chain", %{context: context} do
      input = %{"action" => "quote", "sell_token" => "USDC", "buy_token" => "WETH", "sell_amount" => "100"}
      assert {:error, msg} = EvmSwap.execute(input, context)
      assert msg =~ "Missing required parameter: chain"
    end

    test "rejects unknown chain", %{context: context} do
      input = %{"action" => "quote", "chain" => "solana", "sell_token" => "USDC", "buy_token" => "WETH", "sell_amount" => "100"}
      assert {:error, msg} = EvmSwap.execute(input, context)
      assert msg =~ "Unknown chain"
    end

    test "rejects missing sell_amount", %{context: context} do
      input = %{"action" => "quote", "chain" => "ethereum", "sell_token" => "USDC", "buy_token" => "WETH"}
      assert {:error, msg} = EvmSwap.execute(input, context)
      assert msg =~ "Missing required parameter: sell_amount"
    end

    test "rejects zero sell_amount", %{context: context} do
      input = %{"action" => "quote", "chain" => "ethereum", "sell_token" => "USDC", "buy_token" => "WETH", "sell_amount" => "0"}
      assert {:error, msg} = EvmSwap.execute(input, context)
      assert msg =~ "Amount must be positive"
    end

    test "rejects execute without credential", %{context: context} do
      input = %{"action" => "execute", "chain" => "ethereum", "sell_token" => "USDC", "buy_token" => "WETH", "sell_amount" => "100"}
      assert {:error, msg} = EvmSwap.execute(input, context)
      assert msg =~ "No EVM credential"
    end

    test "rejects execute with invalid credential", %{context: context} do
      ctx = Map.put(context, :credential_value, "not json")
      input = %{"action" => "execute", "chain" => "ethereum", "sell_token" => "USDC", "buy_token" => "WETH", "sell_amount" => "100"}
      assert {:error, msg} = EvmSwap.execute(input, ctx)
      assert msg =~ "Invalid credential JSON"
    end
  end
end
