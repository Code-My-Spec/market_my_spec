# List available recipes
default:
    @just --list

# Run the web app (Postgres, port 4007)
server:
    PORT=4007 iex -S mix phx.server

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
