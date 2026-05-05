{:ok, _} = Application.ensure_all_started(:wallaby)

# Exclude Wallaby browser tests by default — they require ChromeDriver.
# Install with `brew install chromedriver` then run with `mix test --include wallaby`.
ExUnit.configure(exclude: [:wallaby])

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MarketMySpec.Repo, :manual)
