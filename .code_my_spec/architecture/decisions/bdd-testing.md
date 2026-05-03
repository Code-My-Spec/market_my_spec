# Use BDD specs with SexySpex and Wallaby for end-to-end testing

## Status
Accepted (pre-made)

## Context
We need a testing approach that validates user-facing behavior through a real browser and bridges the gap between stories and code.

## Decision
Use BDD specifications with SexySpex (`sexy_spex`) for the Given-When-Then DSL and Wallaby (`wallaby`) for browser-driven interactions. Write specs that test real user workflows through a real browser via ChromeDriver, interacting with LiveView the way a user would — clicking, filling forms, and asserting on visible content.

## Consequences
This is a pre-made decision for the standard CodeMySpec stack.
