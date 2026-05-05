defmodule MarketMySpec.Encrypted.Binary do
  @moduledoc """
  Ecto type for storing encrypted binary values using the application vault.
  """

  use Cloak.Ecto.Binary, vault: MarketMySpec.Vault
end
