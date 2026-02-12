defmodule OneAgent.EVM.Token do
  @moduledoc "Well-known ERC-20 token addresses and utility functions."

  alias OneAgent.EVM.{ABI, RPC}

  @tokens %{
    "ethereum" => %{
      "USDC" => %{address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", decimals: 6},
      "USDT" => %{address: "0xdAC17F958D2ee523a2206206994597C13D831ec7", decimals: 6},
      "WETH" => %{address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", decimals: 18},
      "DAI" => %{address: "0x6B175474E89094C44Da98b954EedeAC495271d0F", decimals: 18}
    },
    "polygon" => %{
      "USDC" => %{address: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359", decimals: 6},
      "USDT" => %{address: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", decimals: 6},
      "WETH" => %{address: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", decimals: 18},
      "DAI" => %{address: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063", decimals: 18}
    },
    "arbitrum" => %{
      "USDC" => %{address: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831", decimals: 6},
      "USDT" => %{address: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9", decimals: 6},
      "WETH" => %{address: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1", decimals: 18},
      "DAI" => %{address: "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1", decimals: 18}
    },
    "base" => %{
      "USDC" => %{address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", decimals: 6},
      "WETH" => %{address: "0x4200000000000000000000000000000000000006", decimals: 18},
      "DAI" => %{address: "0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb", decimals: 18}
    },
    "optimism" => %{
      "USDC" => %{address: "0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85", decimals: 6},
      "USDT" => %{address: "0x94b008aA00579c1307B0EF2c499aD98a8ce58e58", decimals: 6},
      "WETH" => %{address: "0x4200000000000000000000000000000000000006", decimals: 18},
      "DAI" => %{address: "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1", decimals: 18}
    }
  }

  @doc """
  Resolve a token symbol or address to a contract address.
  If the input looks like an address (0x + 40 hex chars), returns it as-is.
  Otherwise, looks up by symbol (case-insensitive).
  """
  def resolve(chain_name, symbol_or_address) when is_binary(symbol_or_address) do
    if address?(symbol_or_address) do
      {:ok, symbol_or_address}
    else
      symbol = String.upcase(symbol_or_address)
      chain_tokens = Map.get(@tokens, chain_name, %{})

      case Map.get(chain_tokens, symbol) do
        %{address: addr} -> {:ok, addr}
        nil -> {:error, "Unknown token '#{symbol_or_address}' on #{chain_name}"}
      end
    end
  end

  @doc """
  Get decimals for a token. Uses static lookup first, falls back to RPC.
  """
  def decimals(chain_name, token_address) do
    # Check static map first
    chain_tokens = Map.get(@tokens, chain_name, %{})

    case Enum.find(chain_tokens, fn {_sym, %{address: addr}} ->
           String.downcase(addr) == String.downcase(token_address)
         end) do
      {_sym, %{decimals: d}} ->
        {:ok, d}

      nil ->
        # RPC fallback
        with {:ok, data} <- ABI.encode_decimals(),
             {:ok, result} <- RPC.eth_call(chain_name, %{"to" => token_address, "data" => data}) do
          ABI.decode_uint256(result)
        end
    end
  end

  @doc "Format a raw token amount to human-readable string."
  def format_amount(raw_amount, decimals) when is_integer(raw_amount) and is_integer(decimals) do
    if decimals == 0 do
      Integer.to_string(raw_amount)
    else
      divisor = Integer.pow(10, decimals)
      whole = div(raw_amount, divisor)
      frac = rem(raw_amount, divisor) |> abs()
      frac_str = frac |> Integer.to_string() |> String.pad_leading(decimals, "0") |> String.trim_trailing("0")

      if frac_str == "" do
        Integer.to_string(whole)
      else
        "#{whole}.#{frac_str}"
      end
    end
  end

  @doc "Convert a human-readable amount string/number to raw integer."
  def to_raw_amount(amount, decimals) when is_binary(amount) and is_integer(decimals) do
    case String.split(amount, ".") do
      [whole] ->
        case Integer.parse(whole) do
          {int, ""} -> {:ok, int * Integer.pow(10, decimals)}
          _ -> {:error, "Invalid amount: #{amount}"}
        end

      [whole, frac] ->
        with {whole_int, ""} <- Integer.parse(whole),
             true <- String.match?(frac, ~r/^\d+$/) do
          # Pad or truncate fractional part to match decimals
          padded = String.pad_trailing(frac, decimals, "0") |> String.slice(0, decimals)
          frac_int = if padded == "", do: 0, else: String.to_integer(padded)
          {:ok, whole_int * Integer.pow(10, decimals) + frac_int}
        else
          _ -> {:error, "Invalid amount: #{amount}"}
        end

      _ ->
        {:error, "Invalid amount: #{amount}"}
    end
  end

  def to_raw_amount(amount, decimals) when is_number(amount) and is_integer(decimals) do
    # Convert number to string first to use precise string-based parsing
    to_raw_amount(:erlang.float_to_binary(amount / 1, [{:decimals, 18}, :compact]), decimals)
  end

  defp address?(str) do
    String.match?(str, ~r/^0x[0-9a-fA-F]{40}$/)
  end
end
