defmodule OneAgent.Tools.EvmBalance do
  @moduledoc """
  Check native and ERC-20 token balances on EVM chains.
  Read-only tool, no credential required for arbitrary addresses.
  """

  @behaviour OneAgent.Tools.Tool

  alias OneAgent.EVM.{ABI, Chain, Credentials, RPC, Token}

  @impl true
  def id, do: "evm_balance"

  @impl true
  def name, do: "EVM Balance"

  @impl true
  def description do
    """
    Check token balances on EVM chains (Ethereum, Polygon, Arbitrum, Base, Optimism). \
    Actions: "native" for ETH/POL balance, "token" for a single ERC-20 balance, \
    "multi" for multiple token balances at once. \
    If no address is provided, uses the wallet from your EVM credential.
    """
  end

  @impl true
  def bucket, do: :evm

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "action" => %{
          "type" => "string",
          "enum" => ["native", "token", "multi"],
          "description" => "Type of balance check"
        },
        "chain" => %{
          "type" => "string",
          "description" => "Chain name: ethereum, polygon, arbitrum, base, optimism"
        },
        "address" => %{
          "type" => "string",
          "description" => "Wallet address (0x...). Optional if EVM credential is configured."
        },
        "token" => %{
          "type" => "string",
          "description" => "Token symbol (USDC, USDT, WETH, DAI) or contract address (action: token)"
        },
        "tokens" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "Array of token symbols or addresses (action: multi)"
        }
      },
      "required" => ["action", "chain"]
    }
  end

  @impl true
  def required_credential_type, do: nil

  @impl true
  def execute(input, context) do
    case input["action"] do
      "native" -> native_balance(input, context)
      "token" -> token_balance(input, context)
      "multi" -> multi_balance(input, context)
      other -> {:error, "Unknown action: #{other}. Use: native, token, multi"}
    end
  end

  defp native_balance(input, context) do
    with {:ok, chain_name} <- validate_chain(input["chain"]),
         {:ok, chain} <- Chain.get(chain_name),
         {:ok, address} <- resolve_address(input["address"], context) do
      case RPC.eth_get_balance(chain_name, address) do
        {:ok, balance_wei} ->
          {:ok, %{
            "balance" => Token.format_amount(balance_wei, chain.native_decimals),
            "token" => chain.native_token,
            "chain" => chain_name,
            "address" => address
          }}

        {:error, reason} ->
          {:error, "Failed to get balance: #{reason}"}
      end
    end
  end

  defp token_balance(input, context) do
    with {:ok, chain_name} <- validate_chain(input["chain"]),
         {:ok, address} <- resolve_address(input["address"], context),
         {:ok, _} <- validate_token_param(input["token"]) do
      token_input = input["token"]

      with {:ok, token_address} <- Token.resolve(chain_name, token_input),
           {:ok, decimals} <- Token.decimals(chain_name, token_address),
           {:ok, data} <- ABI.encode_balance_of(address),
           {:ok, result} <- RPC.eth_call(chain_name, %{"to" => token_address, "data" => data}),
           {:ok, raw_balance} <- ABI.decode_uint256(result) do
        {:ok, %{
          "balance" => Token.format_amount(raw_balance, decimals),
          "token" => String.upcase(token_input),
          "chain" => chain_name,
          "address" => address
        }}
      else
        {:error, reason} -> {:error, "Failed to get token balance: #{reason}"}
      end
    end
  end

  defp multi_balance(input, context) do
    with {:ok, chain_name} <- validate_chain(input["chain"]),
         {:ok, address} <- resolve_address(input["address"], context),
         {:ok, tokens} <- validate_tokens_param(input["tokens"]) do
      balances =
        Enum.map(tokens, fn token_input ->
          case get_single_token_balance(chain_name, address, token_input) do
            {:ok, balance_info} -> balance_info
            {:error, reason} -> %{"token" => token_input, "balance" => "error", "error" => reason}
          end
        end)

      {:ok, %{
        "balances" => balances,
        "chain" => chain_name,
        "address" => address
      }}
    end
  end

  defp get_single_token_balance(chain_name, address, token_input) do
    with {:ok, token_address} <- Token.resolve(chain_name, token_input),
         {:ok, decimals} <- Token.decimals(chain_name, token_address),
         {:ok, data} <- ABI.encode_balance_of(address),
         {:ok, result} <- RPC.eth_call(chain_name, %{"to" => token_address, "data" => data}),
         {:ok, raw_balance} <- ABI.decode_uint256(result) do
      {:ok, %{"token" => String.upcase(token_input), "balance" => Token.format_amount(raw_balance, decimals)}}
    end
  end

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

  defp resolve_address(nil, context) do
    case Credentials.parse_and_derive(context[:credential_value]) do
      {:ok, %{address: address}} -> {:ok, address}
      {:error, _} -> {:error, "No address provided and no EVM credential configured. Provide an address parameter."}
    end
  end

  defp resolve_address(address, _context) when is_binary(address) do
    if Regex.match?(@address_regex, address) do
      {:ok, address}
    else
      {:error, "Invalid address format. Expected 0x followed by 40 hex characters."}
    end
  end

  defp resolve_address(_, _), do: {:error, "Invalid address parameter"}

  defp validate_token_param(nil), do: {:error, "Missing required parameter: token"}
  defp validate_token_param(t) when is_binary(t) and t != "", do: {:ok, t}
  defp validate_token_param(_), do: {:error, "Invalid token parameter"}

  @max_multi_tokens 20

  defp validate_tokens_param(nil), do: {:error, "Missing required parameter: tokens"}

  defp validate_tokens_param(tokens) when is_list(tokens) and length(tokens) > @max_multi_tokens do
    {:error, "Too many tokens: maximum #{@max_multi_tokens} per query"}
  end

  defp validate_tokens_param(tokens) when is_list(tokens) and length(tokens) > 0, do: {:ok, tokens}
  defp validate_tokens_param([]), do: {:error, "tokens array must not be empty"}
  defp validate_tokens_param(_), do: {:error, "Invalid tokens parameter: expected an array"}
end
