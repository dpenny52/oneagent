defmodule OneAgent.Tools.EvmTransfer do
  @moduledoc """
  Send native tokens (ETH/POL) or ERC-20 tokens on EVM chains.
  Requires EVM credential with private key. Fully webhook-restricted.
  """

  @behaviour OneAgent.Tools.Tool

  alias OneAgent.EVM.{ABI, Chain, Credentials, Token, Transaction}

  # Max transfer amount in human-readable units (e.g., 10 ETH or 10,000 USDC)
  @max_native_amount 10
  @max_token_amount 50_000

  @impl true
  def id, do: "evm_transfer"

  @impl true
  def name, do: "EVM Transfer"

  @impl true
  def description do
    """
    Send native tokens (ETH, POL) or ERC-20 tokens on EVM chains. \
    Actions: "send_native" to send ETH/POL, "send_token" to send ERC-20 tokens like USDC. \
    Requires an EVM credential with your wallet private key.
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
          "enum" => ["send_native", "send_token"],
          "description" => "Transfer type"
        },
        "chain" => %{
          "type" => "string",
          "description" => "Chain name: ethereum, polygon, arbitrum, base, optimism"
        },
        "to" => %{
          "type" => "string",
          "description" => "Recipient address (0x...)"
        },
        "amount" => %{
          "type" => "string",
          "description" => "Amount to send in human-readable form (e.g. \"0.1\" for 0.1 ETH)"
        },
        "token" => %{
          "type" => "string",
          "description" => "Token symbol (USDC, USDT, etc.) or contract address (action: send_token)"
        }
      },
      "required" => ["action", "chain", "to", "amount"]
    }
  end

  @impl true
  def required_credential_type, do: :custom

  @impl true
  def execute(input, context) do
    case input["action"] do
      "send_native" -> send_native(input, context)
      "send_token" -> send_token(input, context)
      other -> {:error, "Unknown action: #{other}. Use: send_native, send_token"}
    end
  end

  defp send_native(input, context) do
    with {:ok, chain_name} <- validate_chain(input["chain"]),
         {:ok, chain} <- Chain.get(chain_name),
         {:ok, to} <- validate_address(input["to"]),
         {:ok, amount} <- validate_amount(input["amount"], @max_native_amount),
         {:ok, %{private_key: private_key, address: from}} <- parse_credential(context),
         {:ok, value_wei} <- Token.to_raw_amount(amount, chain.native_decimals) do

      with {:ok, tx} <- Transaction.build(chain_name, from, to, value_wei),
           {:ok, raw_tx} <- Transaction.sign_transaction(tx, private_key),
           {:ok, tx_hash} <- OneAgent.EVM.RPC.eth_send_raw_transaction(chain_name, raw_tx),
           {:ok, receipt} <- Transaction.wait_for_receipt(chain_name, tx_hash) do
        status = if receipt["status"] == "0x1", do: "success", else: "failed"

        {:ok, %{
          "tx_hash" => tx_hash,
          "status" => status,
          "gas_used" => receipt["gasUsed"],
          "explorer_url" => "#{chain.block_explorer}/tx/#{tx_hash}",
          "from" => from,
          "to" => to,
          "amount" => to_string(amount),
          "token" => chain.native_token
        }}
      else
        {:error, :timeout} -> {:error, "Transaction submitted but receipt not confirmed within timeout"}
        {:error, reason} -> {:error, "Transfer failed: #{reason}"}
      end
    end
  end

  defp send_token(input, context) do
    with {:ok, chain_name} <- validate_chain(input["chain"]),
         {:ok, chain} <- Chain.get(chain_name),
         {:ok, to} <- validate_address(input["to"]),
         {:ok, amount} <- validate_amount(input["amount"], @max_token_amount),
         {:ok, _} <- validate_token_param(input["token"]),
         {:ok, %{private_key: private_key, address: from}} <- parse_credential(context),
         {:ok, token_address} <- Token.resolve(chain_name, input["token"]),
         {:ok, decimals} <- Token.decimals(chain_name, token_address),
         {:ok, raw_amount} <- Token.to_raw_amount(amount, decimals) do

      with {:ok, data} <- ABI.encode_transfer(to, raw_amount),
           {:ok, tx} <- Transaction.build(chain_name, from, token_address, 0, data),
           {:ok, raw_tx} <- Transaction.sign_transaction(tx, private_key),
           {:ok, tx_hash} <- OneAgent.EVM.RPC.eth_send_raw_transaction(chain_name, raw_tx),
           {:ok, receipt} <- Transaction.wait_for_receipt(chain_name, tx_hash) do
        status = if receipt["status"] == "0x1", do: "success", else: "failed"

        {:ok, %{
          "tx_hash" => tx_hash,
          "status" => status,
          "gas_used" => receipt["gasUsed"],
          "explorer_url" => "#{chain.block_explorer}/tx/#{tx_hash}",
          "from" => from,
          "to" => to,
          "amount" => to_string(amount),
          "token" => String.upcase(input["token"]),
          "token_address" => token_address
        }}
      else
        {:error, :timeout} -> {:error, "Transaction submitted but receipt not confirmed within timeout"}
        {:error, reason} -> {:error, "Transfer failed: #{reason}"}
      end
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

  defp validate_address(nil), do: {:error, "Missing required parameter: to"}

  defp validate_address(address) when is_binary(address) do
    if Regex.match?(@address_regex, address) do
      {:ok, address}
    else
      {:error, "Invalid address format. Expected 0x followed by 40 hex characters."}
    end
  end

  defp validate_address(_), do: {:error, "Invalid address parameter"}

  defp validate_amount(nil, _max), do: {:error, "Missing required parameter: amount"}

  defp validate_amount(amount, max) when is_binary(amount) do
    case Float.parse(amount) do
      {val, ""} when val > 0 and val <= max -> {:ok, amount}
      {val, ""} when val > max -> {:error, "Amount too large: maximum #{max} per transfer"}
      {_, ""} -> {:error, "Amount must be positive"}
      {_, _rest} -> {:error, "Invalid amount: #{amount}"}
      :error -> {:error, "Invalid amount: #{amount}"}
    end
  end

  defp validate_amount(amount, max) when is_number(amount) and amount > 0 and amount <= max do
    {:ok, to_string(amount)}
  end

  defp validate_amount(amount, max) when is_number(amount) and amount > max do
    {:error, "Amount too large: maximum #{max} per transfer"}
  end

  defp validate_amount(amount, _max) when is_number(amount), do: {:error, "Amount must be positive"}
  defp validate_amount(_, _max), do: {:error, "Invalid amount parameter"}

  defp validate_token_param(nil), do: {:error, "Missing required parameter: token"}
  defp validate_token_param(t) when is_binary(t) and t != "", do: {:ok, t}
  defp validate_token_param(_), do: {:error, "Invalid token parameter"}

  defp parse_credential(context) do
    Credentials.parse_and_derive(context[:credential_value])
  end
end
