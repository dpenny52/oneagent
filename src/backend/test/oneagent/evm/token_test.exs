defmodule OneAgent.EVM.TokenTest do
  use ExUnit.Case, async: true

  alias OneAgent.EVM.Token

  describe "resolve/2" do
    test "resolves USDC on ethereum" do
      assert {:ok, "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"} = Token.resolve("ethereum", "USDC")
    end

    test "is case insensitive" do
      assert {:ok, _} = Token.resolve("ethereum", "usdc")
      assert {:ok, _} = Token.resolve("ethereum", "Usdc")
    end

    test "resolves address pass-through" do
      addr = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
      assert {:ok, ^addr} = Token.resolve("ethereum", addr)
    end

    test "returns error for unknown symbol" do
      assert {:error, msg} = Token.resolve("ethereum", "SHIB")
      assert msg =~ "Unknown token"
    end

    test "resolves tokens on different chains" do
      assert {:ok, _} = Token.resolve("polygon", "USDC")
      assert {:ok, _} = Token.resolve("arbitrum", "USDT")
      assert {:ok, _} = Token.resolve("base", "WETH")
      assert {:ok, _} = Token.resolve("optimism", "DAI")
    end
  end

  describe "decimals/2" do
    test "returns static decimals for known tokens" do
      assert {:ok, 6} = Token.decimals("ethereum", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
      assert {:ok, 18} = Token.decimals("ethereum", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")
    end
  end

  describe "format_amount/2" do
    test "formats with 18 decimals" do
      assert "1" = Token.format_amount(1_000_000_000_000_000_000, 18)
    end

    test "formats with 6 decimals" do
      assert "100" = Token.format_amount(100_000_000, 6)
    end

    test "formats fractional amounts" do
      assert "1.5" = Token.format_amount(1_500_000, 6)
    end

    test "formats zero" do
      assert "0" = Token.format_amount(0, 18)
    end

    test "formats with trailing zeros trimmed" do
      assert "1.1" = Token.format_amount(1_100_000, 6)
    end
  end

  describe "to_raw_amount/2" do
    test "converts string amount" do
      assert {:ok, 1_000_000} = Token.to_raw_amount("1.0", 6)
    end

    test "converts number amount" do
      assert {:ok, 1_000_000_000_000_000_000} = Token.to_raw_amount(1.0, 18)
    end

    test "converts fractional amount" do
      assert {:ok, 500_000} = Token.to_raw_amount("0.5", 6)
    end
  end
end
