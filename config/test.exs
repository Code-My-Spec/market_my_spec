import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Disable AppSignal agent in test — no push to the platform from CI.
config :appsignal, :config, active: false

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :market_my_spec, MarketMySpec.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "market_my_spec_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Endpoint runs in test so Wallaby can drive a real browser against it.
# Set :server back to `false` if you ever need plain unit-test mode without
# Wallaby — but the standard `mix test` flow keeps it on.
config :market_my_spec, MarketMySpecWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "j4Qw3mzj8ePAdijydTCyco5Jam2HdT6iwn3mKYcRGFmpl0TIIb0xVSk9KdHD0ESl",
  server: true

# Wallaby — drives Chrome via chromedriver. Requires `brew install chromedriver`
# (or platform equivalent) on the dev machine. The sandbox flag below is
# read by the Endpoint to mount Phoenix.Ecto.SQL.Sandbox in test only.
config :market_my_spec, :sandbox, Ecto.Adapters.SQL.Sandbox

config :wallaby,
  driver: Wallaby.Chrome,
  otp_app: :market_my_spec,
  screenshot_on_failure: true,
  screenshot_dir: "tmp/wallaby_screenshots"

# In test we don't send emails
config :market_my_spec, MarketMySpec.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Use in-memory ETS backend for file storage in tests (avoids real S3 calls)
config :market_my_spec, :files_backend, MarketMySpec.Files.Memory

# OAuth client credentials for tests. ReqCassette intercepts the actual
# Google/GitHub HTTP calls (see test/support/oauth_spex_helpers.ex), but
# the provider modules still call `Application.fetch_env!/2` for these
# values, so they must be present.
config :market_my_spec,
  google_client_id: "test_google_client_id",
  google_client_secret: "test_google_client_secret",
  github_client_id: "test_github_client_id",
  github_client_secret: "test_github_client_secret"
