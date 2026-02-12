defmodule OneAgent.EVM.ABI do
  @moduledoc "ABI encoding/decoding wrapper using ex_abi."

  # ERC-20 function signatures
  @transfer_sig "transfer(address,uint256)"
  @approve_sig "approve(address,uint256)"
  @balance_of_sig "balanceOf(address)"
  @decimals_sig "decimals()"
  @symbol_sig "symbol()"
  @allowance_sig "allowance(address,address)"

  def encode_transfer(to_address, amount) do
    encode_function_call(@transfer_sig, [to_address, amount])
  end

  def encode_approve(spender_address, amount) do
    encode_function_call(@approve_sig, [spender_address, amount])
  end

  def encode_balance_of(address) do
    encode_function_call(@balance_of_sig, [address])
  end

  def encode_decimals do
    encode_function_call(@decimals_sig, [])
  end

  def encode_symbol do
    encode_function_call(@symbol_sig, [])
  end

  def encode_allowance(owner, spender) do
    encode_function_call(@allowance_sig, [owner, spender])
  end

  @doc "General-purpose ABI function call encoding from a signature string."
  def encode_function_call(signature, args) when is_binary(signature) do
    selector = ABI.Parser.parse!(signature)
    encoded_args = prepare_args(selector.types, args)
    data = ABI.encode(selector, encoded_args)
    {:ok, "0x" <> Base.encode16(data, case: :lower)}
  rescue
    e -> {:error, "ABI encoding failed: #{Exception.message(e)}"}
  end

  @doc "General-purpose ABI function result decoding."
  def decode_function_result(signature, hex_data) when is_binary(signature) and is_binary(hex_data) do
    selector = ABI.Parser.parse!(signature)
    raw = decode_hex_data(hex_data)
    # Tuple signatures put types in :types (not :returns), so use :input
    results = ABI.decode(selector, raw, :input)
    {:ok, results}
  rescue
    e -> {:error, "ABI decoding failed: #{Exception.message(e)}"}
  end

  @doc "Convenience: decode a single uint256 from hex data."
  def decode_uint256(hex_data) do
    raw = decode_hex_data(hex_data)

    case raw do
      <<int::unsigned-big-integer-size(256), _::binary>> ->
        {:ok, int}

      <<int::unsigned-big-integer-size(256)>> ->
        {:ok, int}

      smaller when byte_size(smaller) < 32 ->
        padded = :binary.copy(<<0>>, 32 - byte_size(smaller)) <> smaller
        <<int::unsigned-big-integer-size(256)>> = padded
        {:ok, int}

      _ ->
        {:error, "Failed to decode uint256"}
    end
  rescue
    _ -> {:error, "Failed to decode uint256"}
  end

  @doc "Convenience: decode a string from hex data."
  def decode_string(hex_data) do
    raw = decode_hex_data(hex_data)

    case ABI.decode("(string)", raw) do
      [{str}] when is_binary(str) -> {:ok, str}
      [str] when is_binary(str) -> {:ok, str}
      _ -> {:error, "Failed to decode string"}
    end
  rescue
    _ -> {:error, "Failed to decode string"}
  end

  # Helpers

  defp decode_address("0x" <> hex) do
    {:ok, bytes} = Base.decode16(hex, case: :mixed)
    bytes
  end

  defp decode_address(hex) when is_binary(hex) do
    {:ok, bytes} = Base.decode16(hex, case: :mixed)
    bytes
  end

  defp decode_hex_data("0x" <> hex), do: Base.decode16!(hex, case: :mixed)
  defp decode_hex_data(hex) when is_binary(hex), do: Base.decode16!(hex, case: :mixed)

  defp prepare_args(types, args) when is_list(args) do
    types
    |> Enum.zip(args)
    |> Enum.map(fn
      {:address, arg} when is_binary(arg) -> decode_address(arg)
      {{:uint, _}, arg} when is_binary(arg) -> String.to_integer(arg)
      {{:int, _}, arg} when is_binary(arg) -> String.to_integer(arg)
      {_, arg} -> arg
    end)
  end

  defp prepare_args(_types, args), do: args
end
