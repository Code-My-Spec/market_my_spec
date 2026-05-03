# Use ExVCR for HTTP recording in tests

## Status
Accepted (pre-made)

## Context
We need to test code that makes external HTTP calls without hitting real services in CI.

## Decision
Use ExVCR to record and replay all external HTTP interactions. Record all external calls regardless of the HTTP client used. This ensures deterministic tests and documents the exact API interactions the system depends on.

## Consequences
This is a pre-made decision for the standard CodeMySpec stack.
