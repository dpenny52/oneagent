defmodule OneAgent.EVM.Swap do
  @moduledoc "Paraswap DEX aggregator API client."

  @paraswap_base "https://api.paraswap.io"
  @request_timeout 15_000

  @doc "Get a swap quote from Paraswap."
  def get_quote(chain_id, src_token, dest_token, src_amount, opts \\ %{}) do
    params =
      %{
        srcToken: src_token,
        destToken: dest_token,
        amount: to_string(src_amount),
        side: "SELL",
        network: to_string(chain_id)
      }
      |> Map.merge(opts)

    url = paraswap_base() <> "/prices"

    case Req.get(url, params: params, receive_timeout: @request_timeout) do
      {:ok, %{status: 200, body: %{"priceRoute" => price_route}}} ->
        {:ok, price_route}

      {:ok, %{status: 200, body: body}} ->
        {:error, "Unexpected response: #{sanitize_error(body)}"}

      {:ok, %{status: status, body: body}} ->
        {:error, "Paraswap error #{status}: #{sanitize_error(body)}"}

      {:error, exception} ->
        {:error, "Paraswap request failed: #{Exception.message(exception)}"}
    end
  end

  @doc "Build swap transaction data from a price route."
  def build_swap_tx(chain_id, price_route, user_address, slippage_bps \\ 100) do
    dest_amount = price_route["destAmount"] || "0"

    # Apply slippage to min dest amount
    min_dest =
      case Integer.parse(dest_amount) do
        {amount, _} -> div(amount * (10_000 - slippage_bps), 10_000) |> to_string()
        :error -> dest_amount
      end

    body = %{
      srcToken: price_route["srcToken"],
      destToken: price_route["destToken"],
      srcAmount: price_route["srcAmount"],
      destAmount: min_dest,
      priceRoute: price_route,
      userAddress: user_address,
      slippage: slippage_bps
    }

    url = paraswap_base() <> "/transactions/#{chain_id}"

    case Req.post(url, json: body, receive_timeout: @request_timeout) do
      {:ok, %{status: 200, body: body}} ->
        {:ok,
         %{
           to: body["to"],
           data: body["data"],
           value: body["value"] || "0x0",
           gas: parse_gas(body["gas"])
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, "Paraswap tx build error #{status}: #{sanitize_error(body)}"}

      {:error, exception} ->
        {:error, "Paraswap request failed: #{Exception.message(exception)}"}
    end
  end

  @doc "Extract the tokenTransferProxy (spender) address from a price route."
  def get_spender(price_route) do
    case price_route["tokenTransferProxy"] do
      addr when is_binary(addr) and addr != "" -> {:ok, addr}
      _ -> {:error, "No tokenTransferProxy in price route"}
    end
  end

  defp parse_gas(nil), do: 0

  defp parse_gas(gas) when is_binary(gas) do
    case Integer.parse(gas) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp parse_gas(gas) when is_integer(gas), do: gas

  defp sanitize_error(body) when is_map(body) do
    msg = body["error"] || body["message"] || body["detail"]
    if is_binary(msg), do: msg, else: "see server response"
  end

  defp sanitize_error(body) when is_binary(body), do: String.slice(body, 0, 200)
  defp sanitize_error(_), do: "unknown error"

  defp paraswap_base, do: Application.get_env(:oneagent, :paraswap_base, @paraswap_base)
end
