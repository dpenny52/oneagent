defmodule OneAgent.Tools.EvmRead do
  @moduledoc """
  Read data from smart contracts on EVM chains.
  Read-only tool, no credential required.
  """

  @behaviour OneAgent.Tools.Tool

  alias OneAgent.EVM.{ABI, Chain, RPC}

  @impl true
  def id, do: "evm_read"

  @impl true
  def name, do: "EVM Read"

  @impl true
  def description do
    """
    Read data from smart contracts on EVM chains by calling view/pure functions. \
    Provide the contract address, function signature (e.g. "balanceOf(address)"), \
    and arguments. Optionally specify the return type for decoding.
    """
  end

  @impl true
  def bucket, do: :evm

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "chain" => %{
          "type" => "string",
          "description" => "Chain name: ethereum, polygon, arbitrum, base, optimism"
        },
        "contract" => %{
          "type" => "string",
          "description" => "Contract address (0x...)"
        },
        "function" => %{
          "type" => "string",
          "description" => "Function signature, e.g. \"balanceOf(address)\" or \"totalSupply()\""
        },
        "args" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "Function arguments as strings (addresses, numbers, etc.)"
        },
        "returns" => %{
          "type" => "string",
          "description" => "Return type hint for decoding, e.g. \"uint256\" or \"string\""
        }
      },
      "required" => ["chain", "contract", "function"]
    }
  end

  @impl true
  def required_credential_type, do: nil

  @impl true
  def execute(input, _context) do
    with {:ok, chain_name} <- validate_chain(input["chain"]),
         {:ok, contract} <- validate_address(input["contract"]),
         {:ok, function} <- validate_function(input["function"]) do
      args = input["args"] || []

      case ABI.encode_function_call(function, args) do
        {:ok, data} ->
          case RPC.eth_call(chain_name, %{"to" => contract, "data" => data}) do
            {:ok, result} ->
              decoded = maybe_decode(result, input["returns"], function)

              {:ok, %{
                "result" => decoded,
                "raw" => result,
                "chain" => chain_name,
                "contract" => contract,
                "function" => function
              }}

            {:error, reason} ->
              {:error, "Contract call failed: #{reason}"}
          end

        {:error, reason} ->
          {:error, "Failed to encode function call: #{reason}"}
      end
    end
  end

  defp maybe_decode(hex_result, returns_type, function) do
    cond do
      returns_type == "uint256" ->
        case ABI.decode_uint256(hex_result) do
          {:ok, int} -> int
          _ -> hex_result
        end

      returns_type == "string" ->
        case ABI.decode_string(hex_result) do
          {:ok, str} -> str
          _ -> hex_result
        end

      is_binary(returns_type) and returns_type != "" ->
        # Try to decode using a tuple return signature
        sig = "(#{returns_type})"

        case ABI.decode_function_result(sig, hex_result) do
          {:ok, [result]} -> format_decoded(result)
          {:ok, results} -> Enum.map(results, &format_decoded/1)
          _ -> hex_result
        end

      true ->
        # Try to infer from function signature
        maybe_decode_from_signature(hex_result, function)
    end
  end

  defp maybe_decode_from_signature(hex_result, _function) do
    # Return raw hex if we can't determine the return type
    hex_result
  end

  defp format_decoded(value) when is_binary(value) and byte_size(value) == 20 do
    "0x" <> Base.encode16(value, case: :lower)
  end

  defp format_decoded(value) when is_integer(value), do: value
  defp format_decoded(value) when is_binary(value), do: value
  defp format_decoded(value), do: inspect(value)

  defp validate_chain(nil), do: {:error, "Missing required parameter: chain"}

  defp validate_chain(chain) when is_binary(chain) do
    name = String.downcase(chain)

    if name in Chain.supported_names() do
      {:ok, name}
    else
      {:error, "Unknown chain: #{chain}. Supported: #{Enum.join(Chain.supported_names(), ", ")}"}
    end
  end

  defp validate_chain(_), do: {:error, "Invalid chain parameter"}

  @address_regex ~r/^0x[0-9a-fA-F]{40}$/

  defp validate_address(nil), do: {:error, "Missing required parameter: contract"}

  defp validate_address(address) when is_binary(address) do
    if Regex.match?(@address_regex, address) do
      {:ok, address}
    else
      {:error, "Invalid contract address format. Expected 0x followed by 40 hex characters."}
    end
  end

  defp validate_address(_), do: {:error, "Invalid contract address parameter"}

  defp validate_function(nil), do: {:error, "Missing required parameter: function"}
  defp validate_function(f) when is_binary(f) and f != "", do: {:ok, f}
  defp validate_function(_), do: {:error, "Invalid function parameter"}
end
