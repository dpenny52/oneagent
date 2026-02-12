defmodule OneAgent.Tools.EvmReadTest do
  use OneAgent.DataCase, async: true

  alias OneAgent.Tools.EvmRead

  import OneAgent.AgentsFixtures
  import OneAgent.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    agent = agent_fixture(scope)
    context = %{agent: agent}
    %{agent: agent, context: context}
  end

  describe "metadata" do
    test "id is evm_read" do
      assert EvmRead.id() == "evm_read"
    end

    test "bucket is :evm" do
      assert EvmRead.bucket() == :evm
    end

    test "required_credential_type is nil" do
      assert EvmRead.required_credential_type() == nil
    end
  end

  describe "execute/2 input validation" do
    test "rejects missing chain", %{context: context} do
      input = %{"contract" => "0x0000000000000000000000000000000000000001", "function" => "totalSupply()"}
      assert {:error, msg} = EvmRead.execute(input, context)
      assert msg =~ "Missing required parameter: chain"
    end

    test "rejects unknown chain", %{context: context} do
      input = %{"chain" => "solana", "contract" => "0x0000000000000000000000000000000000000001", "function" => "totalSupply()"}
      assert {:error, msg} = EvmRead.execute(input, context)
      assert msg =~ "Unknown chain"
    end

    test "rejects missing contract", %{context: context} do
      input = %{"chain" => "ethereum", "function" => "totalSupply()"}
      assert {:error, msg} = EvmRead.execute(input, context)
      assert msg =~ "Missing required parameter: contract"
    end

    test "rejects invalid contract address", %{context: context} do
      input = %{"chain" => "ethereum", "contract" => "invalid", "function" => "totalSupply()"}
      assert {:error, msg} = EvmRead.execute(input, context)
      assert msg =~ "Invalid contract address"
    end

    test "rejects missing function", %{context: context} do
      input = %{"chain" => "ethereum", "contract" => "0x0000000000000000000000000000000000000001"}
      assert {:error, msg} = EvmRead.execute(input, context)
      assert msg =~ "Missing required parameter: function"
    end
  end
end
