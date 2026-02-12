defmodule OneAgent.EVM.TransactionTest do
  use ExUnit.Case, async: true

  alias OneAgent.EVM.Transaction

  # Well-known test private key (do NOT use with real funds)
  @test_private_key "0x4c0883a69102937d6231471b5dbb6204fe512961708279f9d92b4d187114d7a5"

  describe "sign_transaction/2" do
    test "signs a type 2 transaction" do
      tx = %Transaction{
        chain_id: 1,
        nonce: 0,
        max_priority_fee_per_gas: 1_000_000_000,
        max_fee_per_gas: 30_000_000_000,
        gas_limit: 21_000,
        to: "0x0000000000000000000000000000000000000001",
        value: 1_000_000_000_000_000_000,
        data: nil,
        access_list: []
      }

      assert {:ok, "0x" <> hex} = Transaction.sign_transaction(tx, @test_private_key)
      # Type 2 transactions start with 02 in the raw bytes
      raw = Base.decode16!(hex, case: :mixed)
      assert <<0x02, _::binary>> = raw
    end

    test "signs a transaction with data" do
      tx = %Transaction{
        chain_id: 1,
        nonce: 5,
        max_priority_fee_per_gas: 2_000_000_000,
        max_fee_per_gas: 50_000_000_000,
        gas_limit: 60_000,
        to: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        value: 0,
        data: "0xa9059cbb0000000000000000000000000000000000000000000000000000000000000001",
        access_list: []
      }

      assert {:ok, "0x" <> _} = Transaction.sign_transaction(tx, @test_private_key)
    end

    test "returns error for invalid private key" do
      tx = %Transaction{
        chain_id: 1,
        nonce: 0,
        max_priority_fee_per_gas: 1_000_000_000,
        max_fee_per_gas: 30_000_000_000,
        gas_limit: 21_000,
        to: "0x0000000000000000000000000000000000000001",
        value: 0,
        data: nil,
        access_list: []
      }

      assert {:error, _} = Transaction.sign_transaction(tx, "0xinvalid")
    end
  end
end
