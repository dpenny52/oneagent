defmodule OneAgent.EVM.ABITest do
  use ExUnit.Case, async: true

  alias OneAgent.EVM.ABI

  @test_address "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"

  describe "encode_transfer/2" do
    test "encodes ERC-20 transfer call" do
      assert {:ok, "0x" <> hex} = ABI.encode_transfer(@test_address, 1_000_000)
      # transfer(address,uint256) selector is a9059cbb
      assert String.starts_with?(hex, "a9059cbb")
    end
  end

  describe "encode_approve/2" do
    test "encodes ERC-20 approve call" do
      assert {:ok, "0x" <> hex} = ABI.encode_approve(@test_address, 1_000_000)
      # approve(address,uint256) selector is 095ea7b3
      assert String.starts_with?(hex, "095ea7b3")
    end
  end

  describe "encode_balance_of/1" do
    test "encodes balanceOf call" do
      assert {:ok, "0x" <> hex} = ABI.encode_balance_of(@test_address)
      # balanceOf(address) selector is 70a08231
      assert String.starts_with?(hex, "70a08231")
    end
  end

  describe "encode_decimals/0" do
    test "encodes decimals call" do
      assert {:ok, "0x" <> hex} = ABI.encode_decimals()
      # decimals() selector is 313ce567
      assert String.starts_with?(hex, "313ce567")
    end
  end

  describe "encode_symbol/0" do
    test "encodes symbol call" do
      assert {:ok, "0x" <> hex} = ABI.encode_symbol()
      # symbol() selector is 95d89b41
      assert String.starts_with?(hex, "95d89b41")
    end
  end

  describe "encode_allowance/2" do
    test "encodes allowance call" do
      owner = "0x0000000000000000000000000000000000000001"
      spender = "0x0000000000000000000000000000000000000002"
      assert {:ok, "0x" <> hex} = ABI.encode_allowance(owner, spender)
      # allowance(address,address) selector is dd62ed3e
      assert String.starts_with?(hex, "dd62ed3e")
    end
  end

  describe "encode_function_call/2" do
    test "encodes arbitrary function" do
      assert {:ok, "0x" <> _} = ABI.encode_function_call("totalSupply()", [])
    end

    test "returns error for invalid signature" do
      assert {:error, _} = ABI.encode_function_call("invalid(((", [])
    end
  end

  describe "decode_uint256/1" do
    test "decodes uint256 from hex" do
      hex = "0x" <> String.duplicate("0", 62) <> "0a"
      assert {:ok, 10} = ABI.decode_uint256(hex)
    end

    test "decodes zero" do
      hex = "0x" <> String.duplicate("0", 64)
      assert {:ok, 0} = ABI.decode_uint256(hex)
    end
  end

  describe "decode_function_result/2" do
    test "decodes uint256 return value" do
      hex = "0x" <> String.duplicate("0", 62) <> "06"
      # Use a tuple signature for decoding output
      assert {:ok, [{6}]} = ABI.decode_function_result("(uint256)", hex)
    end
  end
end
