# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :market_my_spec, :scopes,
  user: [
    default: true,
    module: MarketMySpec.Users.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: MarketMySpec.UsersFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :market_my_spec,
  ecto_repos: [MarketMySpec.Repo],
  generators: [timestamp_type: :utc_datetime]

# Route Nx ops through EXLA's native CPU backend — Scholar.KMeans +
# silhouette_score on the pure-Elixir BinaryBackend takes minutes for
# the ProblemDiscovery Cluster stage; EXLA brings it to milliseconds.
config :nx, default_backend: EXLA.Backend

# Register the pgvector Postgrex extension so the `vector(N)` column type
# round-trips through Ecto. See lib/market_my_spec/postgrex_types.ex.
config :market_my_spec, MarketMySpec.Repo, types: MarketMySpec.PostgrexTypes

# LLM chat defaults for new conversations (operator-configurable, not exposed
# to end users). Provider must be one of the Conversation provider enum
# (:openai | :anthropic); model is the provider-native model id ReqLLM uses.
config :market_my_spec, MarketMySpec.Chat,
  default_provider: :openai,
  default_model: "gpt-5-mini"

config :market_my_spec, :integration_providers, [:google, :github, :codemyspec]

config :market_my_spec, :oauth_providers, %{
  google: MarketMySpec.Integrations.Providers.Google,
  github: MarketMySpec.Integrations.Providers.GitHub,
  codemyspec: MarketMySpec.Integrations.Providers.Codemyspec
}

config :market_my_spec, :codemyspec_url, "https://codemyspec.com"

config :market_my_spec, ExOauth2Provider,
  repo: MarketMySpec.Repo,
  access_token: MarketMySpec.Oauth.AccessToken,
  application: MarketMySpec.Oauth.Application,
  access_grant: MarketMySpec.Oauth.AccessGrant,
  resource_owner: MarketMySpec.Users.User,
  use_refresh_token: true,
  force_ssl_in_redirect_uri: false

config :market_my_spec, MarketMySpec.Vault,
  ciphers: [
    default:
      {Cloak.Ciphers.AES.GCM,
       tag: "AES.GCM.V1",
       key:
         Base.decode64!(
           System.get_env("CLOAK_KEY") || "xrHoeHvdIwokIkl/wbxfdj9Gqb28OiPaen9OBtRQYHw="
         )}
  ]

# Configure the endpoint
config :market_my_spec, MarketMySpecWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MarketMySpecWeb.ErrorHTML, json: MarketMySpecWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MarketMySpec.PubSub,
  live_view: [signing_salt: "AQ8pv9kJ"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :market_my_spec, MarketMySpec.Mailer, adapter: Swoosh.Adapters.Local

# Default `from` for all outbound mail. Overridden per-env via the MAIL_FROM
# env in config/runtime.exs. Address must be on a Resend-verified domain.
config :market_my_spec, :mail_from, {"MarketMySpec", "noreply@marketmyspec.com"}

# Register the text/event-stream MIME type so the :mcp_authenticated pipeline's
# `plug :accepts, ["json", "sse"]` accepts SSE clients that send
# `Accept: text/event-stream` without returning 406 before auth runs.
config :mime, :types, %{"text/event-stream" => ["sse"]}

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  market_my_spec: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  market_my_spec: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# AppSignal — runtime values (push_api_key, name, env, active) come from
# APPSIGNAL_* env vars loaded by MarketMySpec.Secrets at boot from SSM.
# This block exists so the :appsignal app starts; values are env-driven.
config :appsignal, :config, otp_app: :market_my_spec

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
