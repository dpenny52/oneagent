defmodule OneAgent.Polymarket.Credentials do
  @moduledoc """
  Shared credential parsing for Polymarket tools.
  Extracts wallet private key from custom JSON credentials.
  """

  @doc """
  Parses the private key from a credential value (decrypted JSON string).
  Returns {:ok, private_key_hex} or {:error, message}.
  """
  def parse_private_key(nil) do
    {:error, "No Polymarket credential configured. Add a custom credential with your wallet private key JSON."}
  end

  def parse_private_key(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, %{"private_key" => key}} when is_binary(key) and key != "" ->
        {:ok, key}

      {:ok, _} ->
        {:error, "Invalid credential format. Expected JSON: {\"private_key\": \"0x...\"}"}

      {:error, _} ->
        {:error, "Invalid credential JSON. Expected: {\"private_key\": \"0x...\"}"}
    end
  end

  def parse_private_key(_), do: {:error, "Invalid credential value"}
end
