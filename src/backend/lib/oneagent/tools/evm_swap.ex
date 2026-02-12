defmodule OneAgent.Tools.EvmSwap do
  @moduledoc """
  Swap tokens on EVM chains via Paraswap DEX aggregator.
  Requires EVM credential for execute action. Fully webhook-restricted.
  """

  @behaviour OneAgent.Tools.Tool

  alias OneAgent.EVM.{ABI, Chain, Credentials, RPC, Swap, Token, Transaction}

  @native_token_address "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"

  # Known Paraswap Augustus Swapper (router) addresses per chain
  @known_paraswap_routers MapSet.new([
    # Augustus V6.2 (deployed on all major chains at same address)
    "0x6a000f20005980200259b80c5102003040001068",
    # Augustus V6
    "0xdef171fe48cf0115b1d80b88dc8eab59176fee57"
  ])

  @impl true
  def id, do: "evm_swap"

  @impl true
  def name, do: "EVM Swap"

  @impl true
  def description do
    """
    Swap tokens on EVM chains using Paraswap DEX aggregator. \
    Actions: "quote" to get a swap price quote, "execute" to perform the swap. \
    Supports all major tokens (USDC, USDT, WETH, DAI) and native tokens (ETH, POL).
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
          "enum" => ["quote", "execute"],
          "description" => "Swap action"
        },
        "chain" => %{
          "type" => "string",
          "description" => "Chain name: ethereum, polygon, arbitrum, base, optimism"
        },
        "sell_token" => %{
          "type" => "string",
          "description" => "Token to sell (symbol like USDC or contract address). Use 'ETH' or 'POL' for native."
        },
        "buy_token" => %{
          "type" => "string",
          "description" => "Token to buy (symbol like WETH or contract address)"
        },
        "sell_amount" => %{
          "type" => "string",
          "description" => "Amount to sell in human-readable form (e.g. \"100\" for 100 USDC)"
        },
        "slippage_bps" => %{
          "type" => "integer",
          "description" => "Slippage tolerance in basis points (100 = 1%, default 100). Only for execute."
        }
      },
      "required" => ["action", "chain", "sell_token", "buy_token", "sell_amount"]
    }
  end

  @impl true
  def required_credential_type, do: :custom

  @impl true
  def execute(input, context) do
    case input["action"] do
      "quote" -> get_quote(input, context)
      "execute" -> execute_swap(input, context)
      other -> {:error, "Unknown action: #{other}. Use: quote, execute"}
    end
  end

  defp get_quote(input, _context) do
    with {:ok, chain_name} <- validate_chain(input["chain"]),
         {:ok, chain} <- Chain.get(chain_name),
         {:ok, sell_amount} <- validate_amount(input["sell_amount"]),
         {:ok, sell_addr} <- resolve_token_for_swap(chain_name, input["sell_token"]),
         {:ok, buy_addr} <- resolve_token_for_swap(chain_name, input["buy_token"]),
         {:ok, sell_decimals} <- get_token_decimals(chain_name, sell_addr, input["sell_token"]),
         {:ok, buy_decimals} <- get_token_decimals(chain_name, buy_addr, input["buy_token"]),
         {:ok, raw_sell} <- Token.to_raw_amount(sell_amount, sell_decimals) do
      case Swap.get_quote(chain.id, sell_addr, buy_addr, raw_sell) do
        {:ok, price_route} ->
          dest_amount = price_route["destAmount"] || "0"

          case Integer.parse(dest_amount) do
            {dest_int, _} ->
              buy_amount = Token.format_amount(dest_int, buy_decimals)

              {:ok, %{
                "sell_token" => input["sell_token"],
                "buy_token" => input["buy_token"],
                "sell_amount" => to_string(sell_amount),
                "buy_amount" => buy_amount,
                "chain" => chain_name
              }}

            :error ->
              {:error, "Quote failed: invalid destAmount from price route"}
          end

        {:error, reason} ->
          {:error, "Quote failed: #{reason}"}
      end
    end
  end

  defp execute_swap(input, context) do
    slippage_bps = input["slippage_bps"] || 100

    with {:ok, chain_name} <- validate_chain(input["chain"]),
         {:ok, chain} <- Chain.get(chain_name),
         {:ok, sell_amount} <- validate_amount(input["sell_amount"]),
         {:ok, %{private_key: private_key, address: user_address}} <- parse_credential(context),
         {:ok, sell_addr} <- resolve_token_for_swap(chain_name, input["sell_token"]),
         {:ok, buy_addr} <- resolve_token_for_swap(chain_name, input["buy_token"]),
         {:ok, sell_decimals} <- get_token_decimals(chain_name, sell_addr, input["sell_token"]),
         {:ok, buy_decimals} <- get_token_decimals(chain_name, buy_addr, input["buy_token"]),
         {:ok, raw_sell} <- Token.to_raw_amount(sell_amount, sell_decimals) do
      with {:ok, price_route} <- Swap.get_quote(chain.id, sell_addr, buy_addr, raw_sell),
           :ok <- maybe_approve(chain_name, sell_addr, user_address, raw_sell, price_route, private_key),
           {:ok, swap_tx_data} <- Swap.build_swap_tx(chain.id, price_route, user_address, slippage_bps),
           :ok <- validate_router(swap_tx_data.to) do
        # Parse the value from the swap tx
        value = parse_tx_value(swap_tx_data.value)

        with {:ok, tx} <- Transaction.build(chain_name, user_address, swap_tx_data.to, value, swap_tx_data.data),
             {:ok, raw_tx} <- Transaction.sign_transaction(tx, private_key),
             {:ok, tx_hash} <- RPC.eth_send_raw_transaction(chain_name, raw_tx),
             {:ok, receipt} <- Transaction.wait_for_receipt(chain_name, tx_hash) do
          status = if receipt["status"] == "0x1", do: "success", else: "failed"
          dest_amount = price_route["destAmount"] || "0"

          expected_buy =
            case Integer.parse(dest_amount) do
              {dest_int, _} -> Token.format_amount(dest_int, buy_decimals)
              :error -> dest_amount
            end

          {:ok, %{
            "tx_hash" => tx_hash,
            "status" => status,
            "sell_token" => input["sell_token"],
            "buy_token" => input["buy_token"],
            "sell_amount" => to_string(sell_amount),
            "expected_buy_amount" => expected_buy,
            "explorer_url" => "#{chain.block_explorer}/tx/#{tx_hash}"
          }}
        else
          {:error, :timeout} -> {:error, "Swap submitted but receipt not confirmed within timeout"}
          {:error, reason} -> {:error, "Swap failed: #{reason}"}
        end
      else
        {:error, reason} -> {:error, "Swap failed: #{reason}"}
      end
    end
  end

  defp maybe_approve(chain_name, sell_addr, user_address, raw_sell, price_route, private_key) do
    if is_native_token?(sell_addr) do
      :ok
    else
      with {:ok, spender} <- Swap.get_spender(price_route),
           {:ok, allowance_data} <- ABI.encode_allowance(user_address, spender),
           {:ok, allowance_hex} <- RPC.eth_call(chain_name, %{"to" => sell_addr, "data" => allowance_data}),
           {:ok, current_allowance} <- ABI.decode_uint256(allowance_hex) do
        if current_allowance >= raw_sell do
          :ok
        else
          # Approve exact amount needed (not infinite approval for security)
          with {:ok, approve_data} <- ABI.encode_approve(spender, raw_sell),
               {:ok, tx} <- Transaction.build(chain_name, user_address, sell_addr, 0, approve_data),
               {:ok, raw_tx} <- Transaction.sign_transaction(tx, private_key),
               {:ok, tx_hash} <- RPC.eth_send_raw_transaction(chain_name, raw_tx),
               {:ok, receipt} <- Transaction.wait_for_receipt(chain_name, tx_hash) do
            if receipt["status"] == "0x1" do
              :ok
            else
              {:error, "Approval transaction failed"}
            end
          end
        end
      end
    end
  end

  defp is_native_token?(address) do
    String.downcase(address) == String.downcase(@native_token_address)
  end

  defp resolve_token_for_swap(chain_name, token_input) do
    upper = String.upcase(token_input)

    # Treat ETH/POL as native token for Paraswap
    if upper in ["ETH", "POL"] do
      {:ok, @native_token_address}
    else
      Token.resolve(chain_name, token_input)
    end
  end

  defp get_token_decimals(chain_name, address, _input) do
    if is_native_token?(address) do
      {:ok, 18}
    else
      Token.decimals(chain_name, address)
    end
  end

  defp parse_tx_value("0x"), do: 0

  defp parse_tx_value("0x" <> hex) when hex != "" do
    case Integer.parse(hex, 16) do
      {int, ""} -> int
      _ -> 0
    end
  end

  defp parse_tx_value("0"), do: 0
  defp parse_tx_value(val) when is_integer(val), do: val

  defp parse_tx_value(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> int
      _ -> 0
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

  defp validate_amount(nil), do: {:error, "Missing required parameter: sell_amount"}

  defp validate_amount(amount) when is_binary(amount) do
    case Float.parse(amount) do
      {val, ""} when val > 0 -> {:ok, amount}
      {_, ""} -> {:error, "Amount must be positive"}
      {_, _rest} -> {:error, "Invalid amount: #{amount}"}
      :error -> {:error, "Invalid amount: #{amount}"}
    end
  end

  defp validate_amount(amount) when is_number(amount) and amount > 0, do: {:ok, to_string(amount)}
  defp validate_amount(amount) when is_number(amount), do: {:error, "Amount must be positive"}
  defp validate_amount(_), do: {:error, "Invalid amount parameter"}

  defp validate_router(to_address) when is_binary(to_address) do
    if MapSet.member?(@known_paraswap_routers, String.downcase(to_address)) do
      :ok
    else
      {:error, "Swap target address #{to_address} is not a recognized Paraswap router"}
    end
  end

  defp parse_credential(context) do
    Credentials.parse_and_derive(context[:credential_value])
  end
end
