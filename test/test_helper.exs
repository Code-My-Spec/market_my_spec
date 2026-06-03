{:ok, _} = Application.ensure_all_started(:wallaby)

# Exclude Wallaby browser tests by default — they require ChromeDriver.
# `:live` tests hit real provider APIs (cost money, need keys) — run them
# explicitly with `mix test --only live`.
ExUnit.configure(exclude: [:wallaby, :journey, :live])

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MarketMySpec.Repo, :manual)
