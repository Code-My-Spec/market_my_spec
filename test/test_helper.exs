{:ok, _} = Application.ensure_all_started(:wallaby)

# Exclude Wallaby browser tests by default — they require ChromeDriver.
# Install with `brew install chromedriver` then run with `mix test --include wallaby`.
#
# `:journey` is for end-to-end tests under test/journeys/ that hit a deployed
# env. They need ChromeDriver too plus a captured browser session at
# .code_my_spec/qa/sessions/<env>.json. Opt in with `mix test --include journey`.
ExUnit.configure(exclude: [:wallaby, :journey])

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MarketMySpec.Repo, :manual)
