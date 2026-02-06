defmodule OneAgent.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: OneAgent.Vault
end
