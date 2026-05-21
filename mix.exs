defmodule MarketMySpec.MixProject do
  use Mix.Project

  def project do
    [
      app: :market_my_spec,
      version: "0.2.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: compilers(Mix.env()),
      listeners: [Phoenix.CodeReloader],
      releases: releases()
    ]
  end

  defp releases do
    [
      market_my_spec: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent],
        steps: [:assemble, :tar]
      ]
    ] ++ agent_release()
  end

  # The agent binary is a separate Burrito-wrapped release. Only built
  # when Mix.env() is :prod_agent (CI) or :dev_agent (local). In other
  # envs the release entry is omitted entirely so `mix release` and the
  # server build are unaffected.
  defp agent_release do
    if Mix.env() in [:dev_agent, :prod_agent] do
      [
        market_my_spec_agent: [
          steps: [:assemble, &Burrito.wrap/1],
          burrito: [
            targets: burrito_targets(),
            extra_steps: [
              fetch: [pre: [MarketMySpecAgent.Release.PatchLauncherStep]]
            ]
          ]
        ]
      ]
    else
      []
    end
  end

  # When BURRITO_TARGET is set (CI), build only that target.
  # Otherwise build the host-native target for local dev.
  defp burrito_targets do
    case System.get_env("BURRITO_TARGET") do
      "macos_m1" -> [macos_m1: [os: :darwin, cpu: :aarch64]]
      "macos" -> [macos: [os: :darwin, cpu: :x86_64]]
      "linux" -> [linux: [os: :linux, cpu: :x86_64]]
      "linux_aarch64" -> [linux_aarch64: [os: :linux, cpu: :aarch64]]
      _ -> [macos_m1: [os: :darwin, cpu: :aarch64]]
    end
  end

  defp compilers(:test),
    do: [:diagnostics, :boundary, :phoenix_live_view, :erlang, :elixir, :spex, :app]

  defp compilers(_),
    do: [:diagnostics, :boundary, :phoenix_live_view, :erlang, :elixir, :app]

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: app_module(),
      # :ex_aws_ssm and :hackney are listed here so they're booted by the
      # release before MarketMySpec.Secrets.load!/1 is called from
      # config/runtime.exs — no manual Application.ensure_all_started.
      extra_applications: [:logger, :runtime_tools, :ex_aws_ssm, :hackney, :castore]
    ]
  end

  # In :dev_agent / :prod_agent the OTP entry point is the agent's
  # Application (which boots the channel client + auth store). Every
  # other env runs the Phoenix server.
  defp app_module do
    if Mix.env() in [:dev_agent, :prod_agent],
      do: {MarketMySpecAgent.Application, []},
      else: {MarketMySpecWeb.Application, []}
  end

  def cli do
    [
      preferred_envs: [precommit: :test, spex: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  #
  # `lib_agent_release/` holds Burrito build-step modules that
  # reference Burrito.Builder.Context / .Step — only resolvable when
  # Burrito is in the dep tree (:dev_agent / :prod_agent). All other
  # agent code lives in `lib/market_my_spec_agent/` and compiles
  # everywhere; it just never starts unless MarketMySpecAgent.Application
  # is the `mod:` (also gated on agent env).
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(env) when env in [:dev_agent, :prod_agent], do: ["lib", "lib_agent_release"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      # Observability — AppSignal (errors + APM + Phoenix/LiveView/Ecto).
      # Config is env-var driven via APPSIGNAL_* in SSM at /market_my_spec/<env>/.
      {:appsignal, "~> 2.16"},
      {:appsignal_phoenix, "~> 2.5"},
      # SSM-bootstrap secrets at boot — see lib/market_my_spec/secrets.ex.
      # hackney is the HTTP client ExAws uses; listed explicitly so it
      # can go in extra_applications and start with the release before
      # config/runtime.exs runs.
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:ex_aws_ssm, "~> 2.1"},
      {:hackney, "~> 1.20"},
      {:sweet_xml, "~> 0.7"},
      {:phoenix, "~> 1.8.5"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:client_utils, "~> 0.1"},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:sexy_spex, github: "Code-My-Spec/spex", branch: "feature/reusable-givens"},
      {:boundary, "~> 0.10", runtime: false},
      {:assent, "~> 0.3"},
      {:castore, ">= 0.0.0"},
      {:cloak, "~> 1.1"},
      {:cloak_ecto, "~> 1.3"},
      {:dotenvy, "~> 1.1.0"},
      {:ex_oauth2_provider, "~> 0.5.7"},
      {:anubis_mcp, github: "zoedsoupe/anubis-mcp"},
      {:google_api_analytics_admin, "~> 0.26.0"},
      {:tesla, "~> 1.4"},
      {:mdex, "~> 0.5"},
      {:wallaby, "~> 0.30", runtime: false, only: :test},
      {:req_cassette, "~> 0.6.0", only: :test},
      {:code_my_spec_generators, path: "../code_my_spec_generators", only: :dev, runtime: false},

      # MarketMySpecAgent — long-lived channel client for the binary side.
      # Included in every env because the agent module compiles into the
      # main lib/ tree; the server release simply never starts the GenServer.
      {:slipstream, "~> 1.1"},

      # Agent binary release only — Burrito wraps the BEAM into a
      # self-contained executable, Optimus parses argv inside it.
      {:burrito,
       github: "Code-My-Spec/burrito",
       ref: "d44eb28befa146f1c12f6b7b4a2cbc598b3c9686",
       only: [:dev_agent, :prod_agent],
       runtime: false,
       override: true},
      {:optimus, "~> 0.5", only: [:dev_agent, :prod_agent]}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      spex: [
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        "compile",
        "app.start",
        "spex"
      ],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind market_my_spec", "esbuild market_my_spec"],
      "assets.deploy": [
        "tailwind market_my_spec --minify",
        "esbuild market_my_spec --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
