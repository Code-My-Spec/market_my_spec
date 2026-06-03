{:ok, _} = Application.ensure_all_started(:wallaby)

# Exclude Wallaby browser tests by default — they require ChromeDriver.
ExUnit.configure(exclude: [:wallaby, :journey])

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MarketMySpec.Repo, :manual)
