# Use Wallaby for browser-based integration testing

## Status
Accepted (pre-made)

## Context
We need a way to drive a real browser for end-to-end testing that handles LiveView's async rendering and integrates with Ecto's sandbox for database isolation.

## Decision
Use Wallaby (`wallaby`) with ChromeDriver for all browser-based integration tests. It provides concurrent test execution, automatic retry/wait for async content (critical for LiveView), Ecto sandbox integration via user_agent metadata, and a clean DSL for interacting with pages (visit, fill_in, click, assert_has).

## Consequences
This is a pre-made decision for the standard CodeMySpec stack.
