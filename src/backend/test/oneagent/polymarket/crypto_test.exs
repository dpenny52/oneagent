defmodule OneAgent.Polymarket.CryptoTest do
  use ExUnit.Case, async: true

  alias OneAgent.Polymarket.Crypto

  # Well-known test private key (DO NOT use in production)
  @test_private_key "4c0883a69102937d6231471b5dbb6204fe512961708279f24d3b8b7e72b6edc1"
  @test_address "0x364ed35529e5b2b320fddc718c5bd201eaa7e576"

  describe "derive_address/1" do
    test "derives correct address from known private key" do
      assert {:ok, address} = Crypto.derive_address(@test_private_key)
      assert String.downcase(address) == @test_address
    end

    test "handles 0x prefix" do
      assert {:ok, _address} = Crypto.derive_address("0x" <> @test_private_key)
    end

    test "returns error for invalid hex" do
      assert {:error, _} = Crypto.derive_address("not_hex")
    end

    test "returns error for empty string" do
      assert {:error, _} = Crypto.derive_address("")
    end
  end

  describe "hmac_signature/5" do
    test "produces base64url encoded HMAC" do
      result = Crypto.hmac_signature("secret", "12345", "GET", "/api/test")
      assert is_binary(result)
      assert {:ok, _} = Base.url_decode64(result)
    end

    test "different inputs produce different signatures" do
      sig1 = Crypto.hmac_signature("secret", "12345", "GET", "/path1")
      sig2 = Crypto.hmac_signature("secret", "12345", "GET", "/path2")
      assert sig1 != sig2
    end

    test "includes body in signature when provided" do
      sig_no_body = Crypto.hmac_signature("secret", "12345", "POST", "/path")
      sig_with_body = Crypto.hmac_signature("secret", "12345", "POST", "/path", "{\"key\":1}")
      assert sig_no_body != sig_with_body
    end
  end

  describe "sign_typed_data/5" do
    test "produces a valid signature" do
      domain = %{"name" => "Test", "version" => "1", "chainId" => 137}
      types = %{"Test" => [%{"name" => "value", "type" => "string"}]}
      message = %{"value" => "hello"}

      assert {:ok, sig} = Crypto.sign_typed_data(@test_private_key, domain, "Test", types, message)
      assert String.starts_with?(sig, "0x")
      # 65 bytes = 130 hex chars + "0x" prefix
      assert String.length(sig) == 132
    end

    test "returns error for invalid private key" do
      domain = %{"name" => "Test", "version" => "1", "chainId" => 137}
      types = %{"Test" => [%{"name" => "value", "type" => "string"}]}
      message = %{"value" => "hello"}

      assert {:error, _} = Crypto.sign_typed_data("invalid", domain, "Test", types, message)
    end
  end

  describe "sign_clob_auth/1" do
    test "returns auth components" do
      assert {:ok, auth} = Crypto.sign_clob_auth(@test_private_key)
      assert is_binary(auth.signature)
      assert is_integer(auth.timestamp)
      assert is_binary(auth.nonce)
      assert String.starts_with?(auth.address, "0x")
    end
  end

  describe "sign_order/2" do
    test "signs an order struct" do
      order = %{
        "salt" => 12345,
        "maker" => "0x364ed35529e5b2b320fddc718c5bd201eaa7e576",
        "signer" => "0x364ed35529e5b2b320fddc718c5bd201eaa7e576",
        "taker" => "0x0000000000000000000000000000000000000000",
        "tokenId" => "71321045679252212594626385532706912750332728571942532289631379312455583992563",
        "makerAmount" => 1000000,
        "takerAmount" => 500000,
        "expiration" => 0,
        "nonce" => 0,
        "feeRateBps" => 0,
        "side" => 0,
        "signatureType" => 2
      }

      assert {:ok, sig} = Crypto.sign_order(@test_private_key, order)
      assert String.starts_with?(sig, "0x")
    end
  end
end
