# Use phx.gen.auth for authentication

## Status
Accepted (pre-made)

## Context
We need user authentication with registration, login, and session management.

## Decision
Use `mix phx.gen.auth` to generate authentication. It provides a well-tested, customizable authentication system that lives in the project's codebase rather than behind an opaque library.

## Consequences
This is a pre-made decision for the standard CodeMySpec stack.
