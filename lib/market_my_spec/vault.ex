defmodule MarketMySpec.Vault do
  @moduledoc """
  Cloak vault for encrypting sensitive fields at rest.
  """

  use Cloak.Vault, otp_app: :market_my_spec
end
