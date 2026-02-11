defmodule OneAgent.Tools.PolymarketPortfolio do
  @moduledoc """
  View Polymarket portfolio: positions, trade history, and portfolio value.
  Requires `polymarket` bucket with a custom credential containing wallet private key.
  """

  @behaviour OneAgent.Tools.Tool

  alias OneAgent.Polymarket.{Client, Credentials, Crypto}

  @impl true
  def id, do: "polymarket_portfolio"

  @impl true
  def name, do: "Polymarket Portfolio"

  @impl true
  def description do
    """
    View your Polymarket portfolio. Check current positions, trade history, and total portfolio value. \
    Actions: positions (current holdings with P&L), trades (recent trade history), value (total portfolio value).
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
          "enum" => ["positions", "trades", "value"],
          "description" => "The portfolio action to perform"
        },
        "limit" => %{
          "type" => "integer",
          "description" => "Maximum number of results (default 20, max 100). For trades action."
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
      "positions" -> get_positions(context)
      "trades" -> get_trades(input, context)
      "value" -> get_value(context)
      _ -> {:error, "Unknown action: #{action}. Use: positions, trades, value"}
    end
  end

  defp get_positions(context) do
    with {:ok, address} <- get_address(context) do
      case Client.get_positions(address) do
        {:ok, positions} -> {:ok, %{"positions" => positions, "address" => address}}
        {:error, reason} -> {:error, "Failed to get positions: #{reason}"}
      end
    end
  end

  defp get_trades(input, context) do
    with {:ok, address} <- get_address(context) do
      raw_limit = input["limit"]
      limit = if is_integer(raw_limit) and raw_limit > 0, do: min(raw_limit, 100), else: 20

      case Client.get_trades(address, %{limit: limit}) do
        {:ok, trades} -> {:ok, %{"trades" => trades, "address" => address}}
        {:error, reason} -> {:error, "Failed to get trades: #{reason}"}
      end
    end
  end

  defp get_value(context) do
    with {:ok, address} <- get_address(context) do
      case Client.get_portfolio_value(address) do
        {:ok, value} -> {:ok, %{"portfolio_value" => value, "address" => address}}
        {:error, reason} -> {:error, "Failed to get portfolio value: #{reason}"}
      end
    end
  end

  defp get_address(context) do
    with {:ok, key} <- Credentials.parse_private_key(context[:credential_value]) do
      Crypto.derive_address(key)
    end
  end
end
