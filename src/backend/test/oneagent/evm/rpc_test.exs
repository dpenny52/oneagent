defmodule OneAgent.EVM.RPCTest do
  use ExUnit.Case, async: true

  alias OneAgent.EVM.RPC

  describe "decode_hex_quantity/1" do
    test "decodes hex to integer" do
      assert RPC.decode_hex_quantity("0x1a") == 26
      assert RPC.decode_hex_quantity("0x0") == 0
      assert RPC.decode_hex_quantity("0xde0b6b3a7640000") == 1_000_000_000_000_000_000
    end

    test "handles nil" do
      assert RPC.decode_hex_quantity(nil) == 0
    end
  end

  describe "encode_hex_quantity/1" do
    test "encodes integer to hex" do
      assert RPC.encode_hex_quantity(0) == "0x0"
      assert RPC.encode_hex_quantity(26) == "0x1a"
    end
  end
end
