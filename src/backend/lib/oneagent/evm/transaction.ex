defmodule OneAgent.EVM.Transaction do
  @moduledoc "EIP-1559 transaction building and signing."

  alias OneAgent.EVM.{Chain, RPC}

  defstruct [
    :chain_id,
    :nonce,
    :max_priority_fee_per_gas,
    :max_fee_per_gas,
    :gas_limit,
    :to,
    :value,
    :data,
    access_list: []
  ]

  # 500 gwei max gas price cap
  @max_gas_price_gwei 500
  @max_gas_price_wei @max_gas_price_gwei * 1_000_000_000

  @doc """
  Build an EIP-1559 transaction by fetching nonce and gas params from the chain.
  `value` is in wei (integer). `data` is a hex string or nil.
  """
  def build(chain_name, from_address, to_address, value, data \\ nil) do
    with {:ok, chain} <- Chain.get(chain_name) do
      tx_object = build_estimate_object(from_address, to_address, value, data)

      batch_calls = [
        {"eth_getTransactionCount", [from_address, "latest"]},
        {"eth_gasPrice", []},
        {"eth_maxPriorityFeePerGas", []},
        {"eth_estimateGas", [tx_object]}
      ]

      with {:ok, results} <- RPC.batch_call(chain_name, batch_calls) do
        case results do
          [{:ok, nonce_hex}, {:ok, gas_price_hex}, {:ok, priority_fee_hex}, {:ok, gas_hex}] ->
            nonce = RPC.decode_hex_quantity(nonce_hex)
            base_fee = RPC.decode_hex_quantity(gas_price_hex)
            priority_fee = RPC.decode_hex_quantity(priority_fee_hex)
            gas_estimate = RPC.decode_hex_quantity(gas_hex)

            # Add 20% gas buffer (integer arithmetic)
            gas_limit = div(gas_estimate * 6, 5)
            # max_fee = 2 * base_fee + priority_fee (standard EIP-1559 heuristic)
            max_fee = 2 * base_fee + priority_fee

            if max_fee > @max_gas_price_wei do
              {:error, "Gas price too high: #{div(max_fee, 1_000_000_000)} gwei exceeds #{@max_gas_price_gwei} gwei cap"}
            else
              tx = %__MODULE__{
                chain_id: chain.id,
                nonce: nonce,
                max_priority_fee_per_gas: priority_fee,
                max_fee_per_gas: max_fee,
                gas_limit: gas_limit,
                to: to_address,
                value: value || 0,
                data: data
              }

              {:ok, tx}
            end

          results ->
            # Find first error
            case Enum.find(results, fn {:error, _} -> true; _ -> false end) do
              {:error, msg} -> {:error, "RPC error: #{msg}"}
              nil -> {:error, "Unexpected batch results"}
            end
        end
      end
    end
  end

  @doc "Sign an EIP-1559 (type 2) transaction and return the raw hex."
  def sign_transaction(%__MODULE__{} = tx, private_key_hex) do
    with {:ok, privkey_bytes} <- decode_hex(private_key_hex) do
      to_bytes = decode_address_bytes(tx.to)
      data_bytes = decode_data_bytes(tx.data)

      unsigned_fields = [
        int_to_rlp_binary(tx.chain_id),
        int_to_rlp_binary(tx.nonce),
        int_to_rlp_binary(tx.max_priority_fee_per_gas),
        int_to_rlp_binary(tx.max_fee_per_gas),
        int_to_rlp_binary(tx.gas_limit),
        to_bytes,
        int_to_rlp_binary(tx.value),
        data_bytes,
        tx.access_list
      ]

      unsigned_rlp = ExRLP.encode(unsigned_fields)
      # Type 2 envelope: 0x02 || RLP(unsigned)
      unsigned_payload = <<0x02>> <> unsigned_rlp
      tx_hash = ExKeccak.hash_256(unsigned_payload)

      case ExSecp256k1.sign(tx_hash, privkey_bytes) do
        {:ok, {r, s, recovery_id}} ->
          signed_fields =
            unsigned_fields ++
              [
                int_to_rlp_binary(recovery_id),
                strip_leading_zeros(r),
                strip_leading_zeros(s)
              ]

          signed_rlp = ExRLP.encode(signed_fields)
          raw_tx = <<0x02>> <> signed_rlp
          {:ok, "0x" <> Base.encode16(raw_tx, case: :lower)}

        _error ->
          {:error, "Transaction signing failed"}
      end
    end
  end

  @doc "Poll for a transaction receipt with timeout."
  def wait_for_receipt(chain_name, tx_hash, timeout_ms \\ 60_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    poll_receipt(chain_name, tx_hash, deadline)
  end

  defp poll_receipt(chain_name, tx_hash, deadline) do
    if System.monotonic_time(:millisecond) > deadline do
      {:error, :timeout}
    else
      case RPC.eth_get_transaction_receipt(chain_name, tx_hash) do
        {:ok, nil} ->
          Process.sleep(2_000)
          poll_receipt(chain_name, tx_hash, deadline)

        {:ok, receipt} ->
          {:ok, receipt}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Helpers

  defp build_estimate_object(from, to, value, data) do
    obj = %{"from" => from, "to" => to}
    obj = if value && value > 0, do: Map.put(obj, "value", RPC.encode_hex_quantity(value)), else: obj
    if data, do: Map.put(obj, "data", data), else: obj
  end

  defp int_to_rlp_binary(0), do: <<>>

  defp int_to_rlp_binary(int) when is_integer(int) and int > 0 do
    :binary.encode_unsigned(int)
  end

  defp int_to_rlp_binary(int) when is_integer(int) and int < 0 do
    raise ArgumentError, "Cannot RLP-encode negative integer: #{int}"
  end

  defp decode_address_bytes("0x" <> hex) do
    Base.decode16!(hex, case: :mixed)
  end

  defp decode_data_bytes(nil), do: <<>>
  defp decode_data_bytes("0x" <> hex), do: Base.decode16!(hex, case: :mixed)
  defp decode_data_bytes(<<>>), do: <<>>

  defp decode_hex("0x" <> hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> {:error, "Invalid hex in private key"}
    end
  end

  defp decode_hex(hex) when is_binary(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> {:error, "Invalid hex in private key"}
    end
  end

  defp decode_hex(_), do: {:error, "Invalid private key format"}

  defp strip_leading_zeros(<<0, rest::binary>>), do: strip_leading_zeros(rest)
  defp strip_leading_zeros(<<>>), do: <<>>
  defp strip_leading_zeros(bytes), do: bytes
end
