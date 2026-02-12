defmodule OneAgent.EVM.RPC do
  @moduledoc "Stateless JSON-RPC client for EVM chains."

  alias OneAgent.EVM.Chain

  @request_timeout 15_000

  def eth_get_balance(chain_name, address, block \\ "latest") do
    with {:ok, hex} <- rpc_call(chain_name, "eth_getBalance", [address, block]) do
      {:ok, decode_hex_quantity(hex)}
    end
  end

  def eth_get_transaction_count(chain_name, address, block \\ "latest") do
    with {:ok, hex} <- rpc_call(chain_name, "eth_getTransactionCount", [address, block]) do
      {:ok, decode_hex_quantity(hex)}
    end
  end

  def eth_gas_price(chain_name) do
    with {:ok, hex} <- rpc_call(chain_name, "eth_gasPrice", []) do
      {:ok, decode_hex_quantity(hex)}
    end
  end

  def eth_max_priority_fee_per_gas(chain_name) do
    with {:ok, hex} <- rpc_call(chain_name, "eth_maxPriorityFeePerGas", []) do
      {:ok, decode_hex_quantity(hex)}
    end
  end

  def eth_estimate_gas(chain_name, tx_object) do
    with {:ok, hex} <- rpc_call(chain_name, "eth_estimateGas", [tx_object]) do
      {:ok, decode_hex_quantity(hex)}
    end
  end

  def eth_call(chain_name, call_object, block \\ "latest") do
    rpc_call(chain_name, "eth_call", [call_object, block])
  end

  def eth_send_raw_transaction(chain_name, signed_tx_hex) do
    rpc_call(chain_name, "eth_sendRawTransaction", [signed_tx_hex])
  end

  def eth_get_transaction_receipt(chain_name, tx_hash) do
    rpc_call(chain_name, "eth_getTransactionReceipt", [tx_hash])
  end

  @doc "Execute multiple RPC calls in a single HTTP request."
  def batch_call(chain_name, calls) do
    with {:ok, url} <- Chain.rpc_url(chain_name) do
      requests =
        calls
        |> Enum.with_index(1)
        |> Enum.map(fn {{method, params}, id} ->
          %{"jsonrpc" => "2.0", "method" => method, "params" => params, "id" => id}
        end)

      case do_request(url, requests) do
        {:ok, responses} when is_list(responses) ->
          results =
            responses
            |> Enum.sort_by(& &1["id"])
            |> Enum.map(fn resp ->
              if resp["error"] do
                {:error, sanitize_rpc_error(resp["error"])}
              else
                {:ok, resp["result"]}
              end
            end)

          {:ok, results}

        {:ok, _} ->
          {:error, "Unexpected batch response format"}

        {:error, _} = error ->
          error
      end
    end
  end

  # Internal helpers

  defp rpc_call(chain_name, method, params) do
    with {:ok, url} <- Chain.rpc_url(chain_name) do
      body = %{
        "jsonrpc" => "2.0",
        "method" => method,
        "params" => params,
        "id" => 1
      }

      case do_request(url, body) do
        {:ok, %{"error" => error}} ->
          {:error, sanitize_rpc_error(error)}

        {:ok, %{"result" => result}} ->
          {:ok, result}

        {:ok, _} ->
          {:error, "Unexpected RPC response format"}

        {:error, _} = error ->
          error
      end
    end
  end

  defp do_request(url, body) do
    case Req.post(url, json: body, receive_timeout: @request_timeout) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, "RPC HTTP error #{status}"}

      {:error, exception} ->
        {:error, "RPC request failed: #{Exception.message(exception)}"}
    end
  end

  @doc "Decode a hex quantity string (e.g. \"0x1a\") to an integer."
  def decode_hex_quantity("0x"), do: 0

  def decode_hex_quantity("0x" <> hex) when hex != "" do
    case Integer.parse(hex, 16) do
      {int, ""} -> int
      _ -> 0
    end
  end

  def decode_hex_quantity(nil), do: 0

  @doc "Encode an integer to a hex quantity string (e.g. \"0x1a\")."
  def encode_hex_quantity(0), do: "0x0"

  def encode_hex_quantity(int) when is_integer(int) and int > 0 do
    "0x" <> String.downcase(Integer.to_string(int, 16))
  end

  defp sanitize_rpc_error(%{"message" => msg}) when is_binary(msg), do: msg
  defp sanitize_rpc_error(%{"message" => msg}), do: inspect(msg)
  defp sanitize_rpc_error(error), do: "RPC error: #{inspect(error)}"
end
