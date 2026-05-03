defmodule MarketMySpec.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: MarketMySpec.Vault
end
