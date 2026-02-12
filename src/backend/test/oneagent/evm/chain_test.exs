defmodule OneAgent.EVM.ChainTest do
  use ExUnit.Case, async: true

  alias OneAgent.EVM.Chain

  describe "get/1" do
    test "returns ethereum chain" do
      assert {:ok, chain} = Chain.get("ethereum")
      assert chain.id == 1
      assert chain.native_token == "ETH"
      assert chain.eip1559 == true
    end

    test "returns polygon chain" do
      assert {:ok, chain} = Chain.get("polygon")
      assert chain.id == 137
      assert chain.native_token == "POL"
    end

    test "returns arbitrum chain" do
      assert {:ok, chain} = Chain.get("arbitrum")
      assert chain.id == 42161
    end

    test "returns base chain" do
      assert {:ok, chain} = Chain.get("base")
      assert chain.id == 8453
    end

    test "returns optimism chain" do
      assert {:ok, chain} = Chain.get("optimism")
      assert chain.id == 10
    end

    test "is case insensitive" do
      assert {:ok, _} = Chain.get("Ethereum")
      assert {:ok, _} = Chain.get("POLYGON")
    end

    test "returns error for unknown chain" do
      assert {:error, msg} = Chain.get("solana")
      assert msg =~ "Unknown chain"
      assert msg =~ "solana"
    end
  end

  describe "supported_names/0" do
    test "returns sorted list of chain names" do
      names = Chain.supported_names()
      assert "ethereum" in names
      assert "polygon" in names
      assert "arbitrum" in names
      assert "base" in names
      assert "optimism" in names
      assert length(names) == 5
    end
  end

  describe "all/0" do
    test "returns all chain definitions" do
      chains = Chain.all()
      assert length(chains) == 5
      assert Enum.all?(chains, &(&1.__struct__ == Chain))
    end
  end

  describe "rpc_url/1" do
    test "returns default RPC URL" do
      assert {:ok, url} = Chain.rpc_url("ethereum")
      assert url == "https://eth.llamarpc.com"
    end

    test "returns error for unknown chain" do
      assert {:error, _} = Chain.rpc_url("solana")
    end
  end
end
