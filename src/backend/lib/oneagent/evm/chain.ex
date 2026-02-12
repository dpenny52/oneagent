defmodule OneAgent.EVM.Chain do
  @moduledoc "EVM chain definitions and RPC URL resolution."

  defstruct [:id, :name, :short_name, :rpc_url, :native_token, :native_decimals, :block_explorer, :eip1559]

  @chains_data %{
    "ethereum" => {1, "ethereum", "eth", "https://eth.llamarpc.com", "ETH", 18, "https://etherscan.io", true},
    "polygon" => {137, "polygon", "matic", "https://polygon-rpc.com", "POL", 18, "https://polygonscan.com", true},
    "arbitrum" => {42161, "arbitrum", "arb1", "https://arb1.arbitrum.io/rpc", "ETH", 18, "https://arbiscan.io", true},
    "base" => {8453, "base", "base", "https://mainnet.base.org", "ETH", 18, "https://basescan.org", true},
    "optimism" => {10, "optimism", "op", "https://mainnet.optimism.io", "ETH", 18, "https://optimistic.etherscan.io", true}
  }

  defp to_struct({id, name, short_name, rpc_url, native_token, native_decimals, block_explorer, eip1559}) do
    %__MODULE__{
      id: id,
      name: name,
      short_name: short_name,
      rpc_url: rpc_url,
      native_token: native_token,
      native_decimals: native_decimals,
      block_explorer: block_explorer,
      eip1559: eip1559
    }
  end

  @doc "Returns chain definition by name string."
  def get(name) when is_binary(name) do
    case Map.get(@chains_data, String.downcase(name)) do
      nil -> {:error, "Unknown chain: #{name}. Supported: #{Enum.join(supported_names(), ", ")}"}
      data -> {:ok, to_struct(data)}
    end
  end

  @doc "Returns all chain definitions."
  def all do
    Enum.map(@chains_data, fn {_name, data} -> to_struct(data) end)
  end

  @doc "Returns list of supported chain name strings."
  def supported_names, do: Map.keys(@chains_data) |> Enum.sort()

  @doc "Returns the RPC URL for a chain, respecting app env overrides."
  def rpc_url(chain_name) do
    overrides = Application.get_env(:oneagent, :evm_rpc_urls, %{})

    case Map.get(overrides, chain_name) do
      nil ->
        case get(chain_name) do
          {:ok, chain} -> {:ok, chain.rpc_url}
          error -> error
        end

      url ->
        {:ok, url}
    end
  end
end
