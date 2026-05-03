# Use Resend for transactional email

## Status
Accepted (pre-made)

## Context
We need a reliable service for sending transactional emails (account confirmation, password reset, notifications).

## Decision
Use Resend for transactional email delivery. It provides a clean API, good deliverability, and an Elixir-friendly HTTP interface. Pair with Swoosh (`swoosh`) as the Elixir mailer abstraction for testability and local development with Swoosh's built-in mailbox preview.

## Consequences
This is a pre-made decision for the standard CodeMySpec stack.
