import Config

# Production mms-agent binary. Shipped via Homebrew, talks to the
# production MMS server. Mirrors code_my_spec's prod_cli.exs pattern.
config :market_my_spec, env: :prod_agent

config :market_my_spec,
  server_url: "https://marketmyspec.com",
  agent_token_path: "~/.mms-agent/auth.json"

# Server-side stack is unused in agent builds.
config :market_my_spec, MarketMySpecWeb.Endpoint, server: false
config :market_my_spec, ecto_repos: []

config :logger, level: :info
