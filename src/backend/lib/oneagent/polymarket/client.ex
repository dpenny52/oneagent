defmodule OneAgent.Polymarket.Client do
  @moduledoc """
  HTTP client for Polymarket APIs (Gamma, CLOB, Data).
  Stateless module using Req for HTTP requests.
  """

  require Logger

  alias OneAgent.Polymarket.Crypto

  @gamma_base "https://gamma-api.polymarket.com"
  @clob_base "https://clob.polymarket.com"
  @data_base "https://data-api.polymarket.com"
  @request_timeout 15_000

  # ── Gamma API (no auth) ─────────────────────────────────

  def list_events(params \\ %{}) do
    get(gamma_base() <> "/events", params)
  end

  def get_event(event_id) do
    get(gamma_base() <> "/events/#{event_id}")
  end

  def list_markets(params \\ %{}) do
    get(gamma_base() <> "/markets", params)
  end

  def get_market(market_id) do
    get(gamma_base() <> "/markets/#{market_id}")
  end

  # ── CLOB Public API (no auth) ───────────────────────────

  def get_price(token_id, side \\ "buy") do
    get(clob_base() <> "/price", %{token_id: token_id, side: side})
  end

  def get_book(token_id) do
    get(clob_base() <> "/book", %{token_id: token_id})
  end

  def get_midpoint(token_id) do
    get(clob_base() <> "/midpoint", %{token_id: token_id})
  end

  # ── CLOB Auth API ───────────────────────────────────────

  def derive_api_credentials(private_key_hex) do
    with {:ok, auth} <- Crypto.sign_clob_auth(private_key_hex) do
      url = clob_base() <> "/auth/derive-api-key"

      headers = [
        {"POLY_ADDRESS", auth.address},
        {"POLY_SIGNATURE", auth.signature},
        {"POLY_TIMESTAMP", to_string(auth.timestamp)},
        {"POLY_NONCE", auth.nonce}
      ]

      case Req.get(url, headers: headers, receive_timeout: @request_timeout) do
        {:ok, %{status: 200, body: body}} -> {:ok, body}
        {:ok, %{status: status, body: body}} -> {:error, "API error #{status}: #{sanitize_error(body)}"}
        {:error, exception} -> {:error, "Request failed: #{Exception.message(exception)}"}
      end
    end
  end

  def place_order(private_key_hex, api_creds, order_params) do
    with {:ok, signed} <- build_and_sign_order(private_key_hex, order_params) do
      post_authenticated(
        clob_base() <> "/order",
        signed,
        api_creds,
        private_key_hex
      )
    end
  end

  def cancel_order(api_creds, order_id) do
    # Cancel uses DELETE with HMAC auth
    delete_authenticated(
      clob_base() <> "/order/#{order_id}",
      api_creds
    )
  end

  def list_open_orders(api_creds, market_id \\ nil) do
    params = if market_id, do: %{market: market_id}, else: %{}

    get_authenticated(
      clob_base() <> "/orders",
      params,
      api_creds
    )
  end

  # ── Data API (wallet address, no auth) ──────────────────

  def get_positions(address) do
    get(data_base() <> "/positions", %{user: address})
  end

  def get_trades(address, params \\ %{}) do
    get(data_base() <> "/trades", Map.put(params, :user, address))
  end

  def get_portfolio_value(address) do
    get(data_base() <> "/value", %{user: address})
  end

  # ── Internal HTTP helpers ───────────────────────────────

  defp get(url, params \\ %{}) do
    case Req.get(url, params: params, receive_timeout: @request_timeout) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "HTTP #{status}: #{sanitize_error(body)}"}
      {:error, exception} -> {:error, "Request failed: #{Exception.message(exception)}"}
    end
  end

  defp post_authenticated(url, body, api_creds, _private_key_hex) do
    timestamp = to_string(System.system_time(:second))
    path = URI.parse(url).path
    body_json = Jason.encode!(body)

    hmac = Crypto.hmac_signature(api_creds["secret"], timestamp, "POST", path, body_json)

    headers = [
      {"POLY_ADDRESS", api_creds["address"]},
      {"POLY_API_KEY", api_creds["apiKey"]},
      {"POLY_PASSPHRASE", api_creds["passphrase"]},
      {"POLY_TIMESTAMP", timestamp},
      {"POLY_SIGNATURE", hmac}
    ]

    case Req.post(url, json: body, headers: headers, receive_timeout: @request_timeout) do
      {:ok, %{status: status, body: resp}} when status in 200..299 -> {:ok, resp}
      {:ok, %{status: status, body: resp}} -> {:error, "HTTP #{status}: #{sanitize_error(resp)}"}
      {:error, exception} -> {:error, "Request failed: #{Exception.message(exception)}"}
    end
  end

  defp get_authenticated(url, params, api_creds) do
    timestamp = to_string(System.system_time(:second))
    path = URI.parse(url).path
    query = URI.encode_query(params)
    full_path = if query == "", do: path, else: "#{path}?#{query}"

    hmac = Crypto.hmac_signature(api_creds["secret"], timestamp, "GET", full_path)

    headers = [
      {"POLY_ADDRESS", api_creds["address"]},
      {"POLY_API_KEY", api_creds["apiKey"]},
      {"POLY_PASSPHRASE", api_creds["passphrase"]},
      {"POLY_TIMESTAMP", timestamp},
      {"POLY_SIGNATURE", hmac}
    ]

    case Req.get(url, params: params, headers: headers, receive_timeout: @request_timeout) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "HTTP #{status}: #{sanitize_error(body)}"}
      {:error, exception} -> {:error, "Request failed: #{Exception.message(exception)}"}
    end
  end

  defp delete_authenticated(url, api_creds) do
    timestamp = to_string(System.system_time(:second))
    path = URI.parse(url).path

    hmac = Crypto.hmac_signature(api_creds["secret"], timestamp, "DELETE", path)

    headers = [
      {"POLY_ADDRESS", api_creds["address"]},
      {"POLY_API_KEY", api_creds["apiKey"]},
      {"POLY_PASSPHRASE", api_creds["passphrase"]},
      {"POLY_TIMESTAMP", timestamp},
      {"POLY_SIGNATURE", hmac}
    ]

    case Req.request(method: :delete, url: url, headers: headers, receive_timeout: @request_timeout) do
      {:ok, %{status: status, body: resp}} when status in 200..299 -> {:ok, resp}
      {:ok, %{status: status, body: resp}} -> {:error, "HTTP #{status}: #{sanitize_error(resp)}"}
      {:error, exception} -> {:error, "Request failed: #{Exception.message(exception)}"}
    end
  end

  defp build_and_sign_order(private_key_hex, params) do
    with {:ok, address} <- Crypto.derive_address(private_key_hex) do
      salt = :crypto.strong_rand_bytes(32) |> :binary.decode_unsigned()
      # side: 0 = BUY, 1 = SELL
      side = if params["side"] == "sell", do: 1, else: 0

      amount = params["amount"]
      price = params["price"]

      # For BUY: maker pays USDC (makerAmount), receives shares (takerAmount = amount/price)
      # For SELL: maker puts up shares (makerAmount), receives USDC (takerAmount = amount*price)
      {maker_amount, taker_amount} =
        if side == 0 do
          # BUY: spending `amount` USDC at `price` per share → receive amount/price shares
          {to_wei(amount), to_wei(amount / price)}
        else
          # SELL: selling `amount` shares at `price` per share → receive amount*price USDC
          {to_wei(amount), to_wei(amount * price)}
        end

      order = %{
        "salt" => salt,
        "maker" => address,
        "signer" => address,
        "taker" => "0x0000000000000000000000000000000000000000",
        "tokenId" => params["token_id"],
        "makerAmount" => maker_amount,
        "takerAmount" => taker_amount,
        "expiration" => 0,
        "nonce" => 0,
        "feeRateBps" => params["fee_rate_bps"] || 0,
        "side" => side,
        "signatureType" => 2
      }

      case Crypto.sign_order(private_key_hex, order) do
        {:ok, signature} -> {:ok, Map.put(order, "signature", signature)}
        error -> error
      end
    end
  end

  # Convert USDC amount to wei (6 decimals)
  defp to_wei(amount) when is_number(amount), do: round(amount * 1_000_000)
  defp to_wei(amount) when is_binary(amount) do
    case Float.parse(amount) do
      {float, _} -> round(float * 1_000_000)
      :error -> 0
    end
  end

  # Sanitize error bodies to avoid leaking sensitive data (auth headers echoed back, etc.)
  defp sanitize_error(body) when is_map(body) do
    msg = body["message"] || body["error"] || body["detail"]
    if is_binary(msg), do: msg, else: "see server response"
  end

  defp sanitize_error(body) when is_binary(body), do: String.slice(body, 0, 200)
  defp sanitize_error(_), do: "unknown error"

  defp gamma_base, do: Application.get_env(:oneagent, :polymarket_gamma_base, @gamma_base)
  defp clob_base, do: Application.get_env(:oneagent, :polymarket_clob_base, @clob_base)
  defp data_base, do: Application.get_env(:oneagent, :polymarket_data_base, @data_base)
end
