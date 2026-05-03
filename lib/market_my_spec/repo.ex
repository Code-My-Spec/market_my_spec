defmodule MarketMySpec.Repo do
  use Boundary, deps: [], exports: :all

  use Ecto.Repo,
    otp_app: :market_my_spec,
    adapter: Ecto.Adapters.Postgres
end
