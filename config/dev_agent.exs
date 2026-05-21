import Config

# Dev build of the mms-agent binary. Points at a local MMS server so
# the in-repo agent talks to dev, not prod. Mirrors code_my_spec's
# dev_cli.exs pattern.
config :market_my_spec, env: :dev_agent

config :market_my_spec,
  server_url: "http://localhost:4007",
  agent_token_path: "~/.mms-agent/auth.dev.json"

# Server-side stack is unused in agent builds. Repo and the Phoenix
# Endpoint are silenced so an `:ex_aws_ssm` boot doesn't try to
# load secrets that don't exist on the user's machine.
config :market_my_spec, MarketMySpecWeb.Endpoint, server: false
config :market_my_spec, ecto_repos: []

config :logger, level: :info
