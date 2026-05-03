# Use Dotenvy for environment management

## Status
Accepted (pre-made)

## Context
We need a way to manage environment variables across development, test, and production.

## Decision
Use Dotenvy for environment variable management. It loads `.env` files in development and integrates cleanly with Elixir's config system via runtime configuration.

## Consequences
This is a pre-made decision for the standard CodeMySpec stack.
