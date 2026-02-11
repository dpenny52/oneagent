defmodule OneAgent.Polymarket.Crypto do
  @moduledoc """
  Cryptographic utilities for Polymarket integration.
  EIP-712 typed data signing, HMAC-SHA256 for L2 auth, and Ethereum address derivation.
  """

  # Polygon chain ID
  @chain_id 137

  # CTF Exchange contract on Polygon
  @ctf_exchange "0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E"

  @doc """
  Derives an Ethereum address from a hex-encoded private key.
  Returns {:ok, "0x..."} or {:error, reason}.
  """
  def derive_address(private_key_hex) do
    with {:ok, privkey_bytes} <- decode_hex(private_key_hex),
         {:ok, pubkey_bytes} <- ExSecp256k1.create_public_key(privkey_bytes) do
      # Uncompressed pubkey is 65 bytes (0x04 prefix + 64 bytes). Hash the 64 bytes (no prefix).
      <<_prefix::8, xy::binary-size(64)>> = pubkey_bytes
      <<_::binary-size(12), address::binary-size(20)>> = ExKeccak.hash_256(xy)
      {:ok, "0x" <> Base.encode16(address, case: :lower)}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_private_key}
    end
  end

  @doc """
  Creates an HMAC-SHA256 signature for Polymarket CLOB API authentication.
  """
  def hmac_signature(secret, timestamp, method, path, body \\ "") do
    # Official client: direct concatenation, no separators
    message = "#{timestamp}#{String.upcase(method)}#{path}#{body}"

    :crypto.mac(:hmac, :sha256, secret, message)
    |> Base.url_encode64()
  end

  @doc """
  Signs EIP-712 typed data. Used for CLOB auth and order signing.
  Returns {:ok, "0x..." signature} or {:error, reason}.
  """
  def sign_typed_data(private_key_hex, domain, primary_type, types, message) do
    with {:ok, privkey_bytes} <- decode_hex(private_key_hex) do
      domain_type = eip712_domain_type(domain)
      domain_hash = hash_struct("EIP712Domain", domain_type, domain)
      message_hash = hash_struct(primary_type, types, message)

      # EIP-712: "\x19\x01" ++ domainSeparator ++ structHash
      payload = <<0x19, 0x01>> <> domain_hash <> message_hash
      digest = ExKeccak.hash_256(payload)

      case ExSecp256k1.sign(digest, privkey_bytes) do
        {:ok, {r, s, recovery_id}} ->
          # Ethereum convention: v = recovery_id + 27
          sig_hex = Base.encode16(r <> s <> <<recovery_id + 27>>, case: :lower)
          {:ok, "0x" <> sig_hex}

        error ->
          {:error, {:signing_failed, error}}
      end
    end
  end

  @doc """
  Signs a CLOB API authentication message.
  Returns {:ok, %{signature: "0x...", timestamp: ts, nonce: nonce}} or error.
  """
  def sign_clob_auth(private_key_hex, nonce \\ 0) do
    # Timestamp must be in SECONDS (not milliseconds) per official Polymarket client
    timestamp = System.system_time(:second)

    domain = %{
      "name" => "ClobAuthDomain",
      "version" => "1",
      "chainId" => @chain_id
    }

    types = %{
      "ClobAuth" => [
        %{"name" => "address", "type" => "address"},
        %{"name" => "timestamp", "type" => "string"},
        %{"name" => "nonce", "type" => "uint256"},
        %{"name" => "message", "type" => "string"}
      ]
    }

    with {:ok, address} <- derive_address(private_key_hex) do
      message = %{
        "address" => address,
        "timestamp" => to_string(timestamp),
        "nonce" => nonce,
        "message" => "This message attests that I control the given wallet"
      }

      case sign_typed_data(private_key_hex, domain, "ClobAuth", types, message) do
        {:ok, signature} ->
          {:ok, %{signature: signature, timestamp: timestamp, nonce: to_string(nonce), address: address}}

        error ->
          error
      end
    end
  end

  @doc """
  Signs a Polymarket order for the CTF Exchange.
  """
  def sign_order(private_key_hex, %{} = order) do
    domain = %{
      "name" => "Exchange",
      "version" => "1",
      "chainId" => @chain_id,
      "verifyingContract" => @ctf_exchange
    }

    types = %{
      "Order" => [
        %{"name" => "salt", "type" => "uint256"},
        %{"name" => "maker", "type" => "address"},
        %{"name" => "signer", "type" => "address"},
        %{"name" => "taker", "type" => "address"},
        %{"name" => "tokenId", "type" => "uint256"},
        %{"name" => "makerAmount", "type" => "uint256"},
        %{"name" => "takerAmount", "type" => "uint256"},
        %{"name" => "expiration", "type" => "uint256"},
        %{"name" => "nonce", "type" => "uint256"},
        %{"name" => "feeRateBps", "type" => "uint256"},
        %{"name" => "side", "type" => "uint8"},
        %{"name" => "signatureType", "type" => "uint8"}
      ]
    }

    sign_typed_data(private_key_hex, domain, "Order", types, order)
  end

  # ── Internal EIP-712 helpers ──────────────────────────────

  defp eip712_domain_type(domain) do
    # Build EIP-712 domain type dynamically based on which fields are present
    fields =
      [
        {"name", "string"},
        {"version", "string"},
        {"chainId", "uint256"},
        {"verifyingContract", "address"},
        {"salt", "bytes32"}
      ]
      |> Enum.filter(fn {name, _type} -> Map.has_key?(domain, name) end)
      |> Enum.map(fn {name, type} -> %{"name" => name, "type" => type} end)

    %{"EIP712Domain" => fields}
  end

  defp hash_struct(type_name, types, data) do
    type_hash = encode_type(type_name, types) |> ExKeccak.hash_256()
    encoded_values = encode_data(type_name, types, data)
    ExKeccak.hash_256(type_hash <> encoded_values)
  end

  defp encode_type(primary_type, types) do
    fields = Map.get(types, primary_type, [])
    field_str = Enum.map_join(fields, ",", fn %{"name" => n, "type" => t} -> "#{t} #{n}" end)
    "#{primary_type}(#{field_str})"
  end

  defp encode_data(type_name, types, data) do
    fields = Map.get(types, type_name, [])

    Enum.map(fields, fn %{"name" => name, "type" => type} ->
      value = Map.get(data, name) || Map.get(data, to_string(name))
      encode_value(type, value)
    end)
    |> IO.iodata_to_binary()
  end

  defp encode_value("string", value) when is_binary(value) do
    ExKeccak.hash_256(value) |> pad_left(32)
  end

  defp encode_value("address", "0x" <> hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, bytes} -> pad_left(bytes, 32)
      :error -> pad_left(<<0::160>>, 32)
    end
  end

  defp encode_value("address", value) when is_binary(value), do: pad_left(<<0::160>>, 32)

  defp encode_value("uint256", value) when is_integer(value) and value >= 0 do
    <<value::unsigned-big-integer-size(256)>>
  end

  defp encode_value("uint256", value) when is_integer(value), do: <<0::256>>

  defp encode_value("uint256", value) when is_binary(value) do
    case Integer.parse(value) do
      {int_val, _} -> <<int_val::unsigned-big-integer-size(256)>>
      :error -> <<0::256>>
    end
  end

  defp encode_value("uint8", value) when is_integer(value) and value >= 0 do
    <<value::unsigned-big-integer-size(256)>>
  end

  defp encode_value("uint8", value) when is_integer(value), do: <<0::256>>

  defp encode_value("uint8", value) when is_binary(value) do
    case Integer.parse(value) do
      {int_val, _} -> <<int_val::unsigned-big-integer-size(256)>>
      :error -> <<0::256>>
    end
  end

  defp encode_value("bool", true), do: <<1::unsigned-big-integer-size(256)>>
  defp encode_value("bool", false), do: <<0::unsigned-big-integer-size(256)>>

  defp encode_value(_type, _value), do: <<0::256>>

  defp pad_left(bytes, target_size) when byte_size(bytes) == target_size, do: bytes
  defp pad_left(bytes, target_size) when byte_size(bytes) > target_size do
    # Take rightmost target_size bytes (ABI encoding convention)
    skip = byte_size(bytes) - target_size
    <<_::binary-size(skip), result::binary-size(target_size)>> = bytes
    result
  end
  defp pad_left(bytes, target_size) do
    padding_size = (target_size - byte_size(bytes)) * 8
    <<0::size(padding_size)>> <> bytes
  end

  defp decode_hex("0x" <> hex), do: decode_hex_string(hex)
  defp decode_hex(hex) when is_binary(hex), do: decode_hex_string(hex)
  defp decode_hex(_), do: {:error, :invalid_hex}

  defp decode_hex_string(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> {:error, :invalid_hex}
    end
  end
end
