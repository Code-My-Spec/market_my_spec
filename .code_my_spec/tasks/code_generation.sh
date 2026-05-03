#!/bin/bash
# Code generation script — produced by CodeMySpec code_generation task
# Re-run on a fresh Phoenix project to reproduce this scaffold.
#
# Prerequisites:
#   - Fresh `mix phx.new market_my_spec --live` Phoenix 1.8 project
#   - code_my_spec_generators added as a path or hex dep:
#       {:code_my_spec_generators, path: "../code_my_spec_generators", only: :dev, runtime: false}
#   - mix deps.get && mix deps.compile code_my_spec_generators
#
# Skipped generators (intentional — not story-driven for MMS):
#   - mix cms_gen.accounts          (no multi-tenancy stories; single-user SaaS)
#   - mix cms_gen.feedback_widget   (no story drives an embedded feedback widget)

set -e

# Authentication (LiveView): users, sessions, magic-link confirmation, settings.
# Generates the Users domain context plus web-side auth scaffolding.
mix phx.gen.auth Users User users --live

mix deps.get

# OAuth integrations: encrypted token storage (Cloak), integrations context,
# OAuth controller + LiveView listing, ETS-backed state store, provider behaviour.
# Required for the GitHub/Google sign-in stories (672/673) — captures the user via OAuth.
# Add deps before running: {:assent, "~> 0.3"}, {:cloak, "~> 1.1"}, {:cloak_ecto, "~> 1.3"}
mix cms_gen.integrations

# Provider implementations (one file each under lib/market_my_spec/integrations/providers/).
mix cms_gen.integration_provider Google google
mix cms_gen.integration_provider GitHub github

mix deps.get
mix ecto.create
mix ecto.migrate
