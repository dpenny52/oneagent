defmodule OneAgent.Tools.PolymarketMarkets do
  @moduledoc """
  Browse and search Polymarket prediction markets, get prices and orderbooks.
  Requires `polymarket` bucket. No credential needed for market data.
  """

  @behaviour OneAgent.Tools.Tool

  alias OneAgent.Polymarket.Client

  @impl true
  def id, do: "polymarket_markets"

  @impl true
  def name, do: "Polymarket Markets"

  @impl true
  def description do
    """
    Browse and search Polymarket prediction markets. Prices represent probabilities \
    (0.65 = 65% implied probability). Actions: search (find markets by keyword), \
    get_event (event details with all markets), get_market (single market details \
    with YES/NO token IDs), get_price (current price for a token), get_book (full orderbook). \
    Use get_market to find token IDs, then get_price to check current prices before trading.
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
          "enum" => ["search", "get_event", "get_market", "get_price", "get_book"],
          "description" => "The action to perform"
        },
        "query" => %{
          "type" => "string",
          "description" => "Search query for finding markets (action: search)"
        },
        "event_id" => %{
          "type" => "string",
          "description" => "Event ID (action: get_event)"
        },
        "market_id" => %{
          "type" => "string",
          "description" => "Market condition ID (action: get_market)"
        },
        "token_id" => %{
          "type" => "string",
          "description" => "Token ID for price/book lookup (action: get_price, get_book)"
        },
        "side" => %{
          "type" => "string",
          "enum" => ["buy", "sell"],
          "description" => "Price side (default: buy) (action: get_price)"
        }
      },
      "required" => ["action"]
    }
  end

  @impl true
  def required_credential_type, do: nil

  @impl true
  def execute(input, _context) do
    action = input["action"]

    case action do
      "search" -> search_markets(input)
      "get_event" -> get_event(input)
      "get_market" -> get_market(input)
      "get_price" -> get_price(input)
      "get_book" -> get_book(input)
      _ -> {:error, "Unknown action: #{action}. Use: search, get_event, get_market, get_price, get_book"}
    end
  end

  defp search_markets(input) do
    query = input["query"]

    if !is_binary(query) or String.trim(query) == "" do
      {:error, "Missing required parameter: query (search text)"}
    else
      case Client.search(query) do
        {:ok, %{"events" => events}} when is_list(events) ->
          {:ok, %{"events" => format_search_events(events), "query" => query}}

        {:ok, _} ->
          {:ok, %{"events" => [], "query" => query}}

        {:error, reason} ->
          {:error, "Failed to search markets: #{reason}"}
      end
    end
  end

  defp get_event(input) do
    event_id = input["event_id"]

    if !is_binary(event_id) or String.trim(event_id) == "" do
      {:error, "Missing required parameter: event_id"}
    else
      case Client.get_event(event_id) do
        {:ok, event} -> {:ok, format_event_detail(event)}
        {:error, reason} -> {:error, "Failed to get event: #{reason}"}
      end
    end
  end

  defp get_market(input) do
    market_id = input["market_id"]

    if !is_binary(market_id) or String.trim(market_id) == "" do
      {:error, "Missing required parameter: market_id"}
    else
      case Client.get_market(market_id) do
        {:ok, market} -> {:ok, format_market_detail(market)}
        {:error, reason} -> {:error, "Failed to get market: #{reason}"}
      end
    end
  end

  defp get_price(input) do
    token_id = input["token_id"]

    if !is_binary(token_id) or String.trim(token_id) == "" do
      {:error, "Missing required parameter: token_id (use get_market to find token IDs)"}
    else
      side = if input["side"] in ["buy", "sell"], do: input["side"], else: "buy"

      case Client.get_price(token_id, side) do
        {:ok, price_data} -> {:ok, price_data}
        {:error, reason} -> {:error, "Failed to get price: #{reason}"}
      end
    end
  end

  defp get_book(input) do
    token_id = input["token_id"]

    if !is_binary(token_id) or String.trim(token_id) == "" do
      {:error, "Missing required parameter: token_id"}
    else
      case Client.get_book(token_id) do
        {:ok, book} -> {:ok, book}
        {:error, reason} -> {:error, "Failed to get orderbook: #{reason}"}
      end
    end
  end

  # /public-search returns camelCase fields (conditionId vs condition_id)
  defp format_search_events(events) when is_list(events) do
    Enum.map(events, fn e ->
      markets =
        (e["markets"] || [])
        |> Enum.take(5)
        |> Enum.map(fn m ->
          %{
            "condition_id" => m["conditionId"] || m["condition_id"],
            "question" => m["question"],
            "outcomes" => m["outcomes"],
            "tokens" => m["clobTokenIds"],
            "outcome_prices" => m["outcomePrices"]
          }
        end)

      %{
        "id" => e["id"],
        "title" => e["title"],
        "description" => truncate(e["description"], 200),
        "active" => e["active"],
        "markets" => markets
      }
    end)
  end

  defp format_search_events(_), do: []

  defp format_event_detail(event) do
    markets =
      (event["markets"] || [])
      |> Enum.map(fn m ->
        %{
          "condition_id" => m["condition_id"],
          "question" => m["question"],
          "outcomes" => m["outcomes"],
          "tokens" => m["clobTokenIds"]
        }
      end)

    %{
      "id" => event["id"],
      "title" => event["title"],
      "description" => event["description"],
      "markets" => markets
    }
  end

  defp format_market_detail(market) do
    %{
      "condition_id" => market["condition_id"],
      "question" => market["question"],
      "description" => market["description"],
      "outcomes" => market["outcomes"],
      "token_ids" => market["clobTokenIds"],
      "active" => market["active"],
      "volume" => market["volume"],
      "liquidity" => market["liquidity"]
    }
  end

  defp truncate(nil, _), do: nil
  defp truncate(str, max) when byte_size(str) <= max, do: str
  defp truncate(str, max), do: String.slice(str, 0, max) <> "..."
end
