defmodule OneAgent.Tools.PolymarketTrade do
  @moduledoc """
  Execute trades on Polymarket. Requires `polymarket` bucket with a custom credential
  containing the wallet private key. Fully webhook-restricted.
  """

  @behaviour OneAgent.Tools.Tool

  alias OneAgent.Polymarket.Client

  @max_trade_amount 10_000

  @impl true
  def id, do: "polymarket_trade"

  @impl true
  def name, do: "Polymarket Trade"

  @impl true
  def description do
    """
    Buy or sell outcome tokens on Polymarket prediction markets. \
    Buying YES at 0.65 means paying $0.65 per share for a token that pays $1 if the outcome happens \
    (65% implied probability). Use polymarket_markets tool first to find token IDs and check prices. \
    Actions: buy, sell, cancel, list_orders.
    """
  end

  @impl true
  def bucket, do: :polymarket

  @impl true
  def parameters_schema do
    %{
      "type" => "object",
      "properties" => %{
        "action" => %{
          "type" => "string",
          "enum" => ["buy", "sell", "cancel", "list_orders"],
          "description" => "The trading action to perform"
        },
        "token_id" => %{
          "type" => "string",
          "description" => "Token ID to trade (action: buy, sell). Get from polymarket_markets get_market."
        },
        "amount" => %{
          "type" => "number",
          "description" => "Amount in USDC to spend (buy) or number of shares to sell (sell). Must be positive."
        },
        "price" => %{
          "type" => "number",
          "description" => "Limit price per share (0.01 to 0.99). Represents probability."
        },
        "order_id" => %{
          "type" => "string",
          "description" => "Order ID to cancel (action: cancel)"
        },
        "market_id" => %{
          "type" => "string",
          "description" => "Filter orders by market (action: list_orders, optional)"
        }
      },
      "required" => ["action"]
    }
  end

  @impl true
  def required_credential_type, do: :custom

  @impl true
  def execute(input, context) do
    action = input["action"]

    case action do
      "buy" -> execute_trade(input, "buy", context)
      "sell" -> execute_trade(input, "sell", context)
      "cancel" -> cancel_order(input, context)
      "list_orders" -> list_orders(input, context)
      _ -> {:error, "Unknown action: #{action}. Use: buy, sell, cancel, list_orders"}
    end
  end

  defp execute_trade(input, side, context) do
    with :ok <- validate_trade_params(input),
         {:ok, private_key} <- parse_credential(context) do
      order_params = %{
        "token_id" => input["token_id"],
        "amount" => input["amount"],
        "price" => input["price"],
        "side" => side
      }

      with {:ok, api_creds} <- Client.derive_api_credentials(private_key),
           {:ok, result} <- Client.place_order(private_key, api_creds, order_params) do
        {:ok, %{
          "action" => side,
          "token_id" => input["token_id"],
          "amount" => input["amount"],
          "price" => input["price"],
          "order" => result
        }}
      else
        {:error, reason} -> {:error, "Trade failed: #{reason}"}
      end
    end
  end

  # Only allow alphanumeric, hyphens, and underscores in order IDs (prevent path traversal)
  @order_id_regex ~r/^[a-zA-Z0-9_\-]+$/

  defp cancel_order(input, context) do
    order_id = input["order_id"]

    cond do
      !is_binary(order_id) or String.trim(order_id) == "" ->
        {:error, "Missing required parameter: order_id"}

      not Regex.match?(@order_id_regex, order_id) ->
        {:error, "Invalid order_id format"}

      true ->
        with {:ok, private_key} <- parse_credential(context),
             {:ok, api_creds} <- Client.derive_api_credentials(private_key),
             {:ok, result} <- Client.cancel_order(api_creds, order_id) do
          {:ok, %{"cancelled" => order_id, "result" => result}}
        else
          {:error, reason} -> {:error, "Cancel failed: #{reason}"}
        end
    end
  end

  defp list_orders(input, context) do
    with {:ok, private_key} <- parse_credential(context),
         {:ok, api_creds} <- Client.derive_api_credentials(private_key) do
      case Client.list_open_orders(api_creds, input["market_id"]) do
        {:ok, orders} -> {:ok, %{"orders" => orders}}
        {:error, reason} -> {:error, "Failed to list orders: #{reason}"}
      end
    end
  end

  defp validate_trade_params(input) do
    token_id = input["token_id"]
    amount = input["amount"]
    price = input["price"]

    cond do
      !is_binary(token_id) or String.trim(token_id) == "" ->
        {:error, "Missing required parameter: token_id"}

      !is_number(amount) or amount <= 0 ->
        {:error, "Invalid amount: must be a positive number"}

      amount > @max_trade_amount ->
        {:error, "Amount too large: maximum #{@max_trade_amount} USDC per trade"}

      !is_number(price) or price < 0.01 or price > 0.99 ->
        {:error, "Invalid price: must be between 0.01 and 0.99 (probability)"}

      true ->
        :ok
    end
  end

  defp parse_credential(context) do
    OneAgent.Polymarket.Credentials.parse_private_key(context[:credential_value])
  end
end
