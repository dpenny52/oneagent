defmodule OneAgent.EVM.Credentials do
  @moduledoc "Credential parsing for EVM tools."

  @doc "Parses the private key from a decrypted credential JSON string."
  def parse_private_key(nil) do
    {:error, "No EVM credential configured. Add a custom credential with your wallet private key JSON."}
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

  @doc "Derives an Ethereum address from a private key hex string."
  def derive_address(private_key_hex) do
    OneAgent.Polymarket.Crypto.derive_address(private_key_hex)
  end

  @doc "Parse credential and derive address in one step."
  def parse_and_derive(credential_value) do
    with {:ok, private_key} <- parse_private_key(credential_value),
         {:ok, address} <- derive_address(private_key) do
      {:ok, %{private_key: private_key, address: address}}
    end
  end
end
