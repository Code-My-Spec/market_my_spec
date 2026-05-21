# List available recipes
default:
    @just --list

# Run the web app (Postgres, port 4007)
server:
    PORT=4007 iex -S mix phx.server

# Run the MMS Agent locally as a plain Mix app (no Burrito wrap).
# Boots MarketMySpecAgent.Application's supervision tree — Auth.Store
# reads ~/.mms-agent/auth.dev.json (dev_agent uses its own credential
# file so a dev pairing doesn't clobber prod), Channel.Client tries to
# join the user topic on the configured server_url
# (see config/dev_agent.exs — defaults to http://localhost:4007).
#
# Subcommands:
#   `just agent`       → iex session for poking at supervisor state etc.
#   `just agent pair`  → boots the tree, calls MarketMySpecAgent.Pairing.run/0,
#                        and exits (one-shot pairing flow against the dev server).
agent ACTION="run":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ACTION}}" in
      run)
        MIX_ENV=dev_agent iex -S mix run --no-halt
        ;;
      pair)
        MIX_ENV=dev_agent mix run --no-halt -e 'MarketMySpecAgent.Pairing.run()'
        ;;
      *)
        echo "unknown action: {{ACTION}} (want: run | pair)" >&2
        exit 1
        ;;
    esac

# Build the Burrito binary. Only needed before shipping or to verify
# the packaged binary actually launches — day-to-day QA uses `just agent`.
build-agent:
    MIX_ENV=prod_agent mix release market_my_spec_agent

# Run tests
test *args:
    mix test {{args}}

# Run BDD spex
spex *args:
    mix spex {{args}}

# Setup: deps + db
setup:
    mix deps.get && mix ecto.setup

# Reset the dev database
reset-db:
    mix ecto.reset

# Compile with warnings as errors
check:
    mix compile --warnings-as-errors

# Cut a new agent release. Bumps mix.exs + config.exs to VERSION, commits,
# tags v<VERSION>, and pushes commit + tag — CI (.github/workflows/release.yml)
# picks up the tag, builds all four Burrito targets, and creates a GitHub Release.
# Usage: just release 0.2.0
release VERSION:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! echo "{{VERSION}}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
      echo "Bad version: {{VERSION}} (want N.N.N)" >&2
      exit 1
    fi
    if [ -n "$(git status --porcelain)" ]; then
      echo "Working tree dirty — commit or stash first." >&2
      exit 1
    fi
    sed -i.bak -E 's/^      version: "[0-9]+\.[0-9]+\.[0-9]+",/      version: "{{VERSION}}",/' mix.exs
    sed -i.bak -E 's/^  agent_latest_version: "[0-9]+\.[0-9]+\.[0-9]+",/  agent_latest_version: "{{VERSION}}",/' config/config.exs
    rm -f mix.exs.bak config/config.exs.bak
    git add mix.exs config/config.exs
    git commit -m "Release v{{VERSION}}"
    git tag "v{{VERSION}}"
    git push origin HEAD
    git push origin "v{{VERSION}}"
    echo
    echo "Tag v{{VERSION}} pushed. CI is now building the binaries."
    echo "Track progress at:"
    echo "  https://github.com/Code-My-Spec/market_my_spec/actions"
