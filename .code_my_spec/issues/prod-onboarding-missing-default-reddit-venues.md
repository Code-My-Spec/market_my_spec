# Prod MMS ships with zero Reddit venues by default

Filed 2026-05-22 from MMS MCP usage during the CodeMySpec marketing cycle.

## Problem

When the operator switched the MMS MCP connection from dev to prod today, `list_venues` returned only 4 ElixirForum venues — zero Reddit venues. Dev had 6 Reddit venues seeded; prod had none.

Bootstrapping to working state required:

- `add_venue` × 6 (ClaudeAI, ChatGPTCoding, elixir, vibecoding, programming, AskProgramming) with reasonable weights
- `update_search` × 5 to wire the new Reddit venues into the existing saved searches
- `create_search` × 1 for the "Harness conversation (live)" lane that dev had but prod didn't

Took 5-10 minutes of manual setup that wasn't surfaced by any onboarding flow.

## Why it matters

The operator's CMS strategy (`marketing/07_channels.md`) names Reddit as the primary inner-ring channel. Shipping a "marketing harness" without the dominant channel pre-wired is a paper cut at best and a real activation blocker at worst. Hit it directly today.

## Acceptance criteria

1. **Seed the recommended Reddit venue set on prod onboarding.** New accounts get the default 6 Reddit venues at the same weights dev uses: ClaudeAI (0.9), ChatGPTCoding (0.9), elixir (0.9), vibecoding (0.7), programming (0.5), AskProgramming (0.5). Plus the 4 EF venues that already ship (once `elixirforum-venue-identifier-mapping` is resolved).
2. **Seed the canonical saved-search set** with venue wiring already in place. Today's dev had 6 saved searches; prod had 5. The "Harness conversation (live)" lane was missing from prod.
3. **Make the default set explicit in operator-facing docs** — when a new operator runs `list_venues` on a fresh account, the result should include the default set, not be empty.
4. **Allow operators to override** — if they want a different venue mix (e.g. an MMS-server operator who's not in the CMS engineer audience), they can `remove_venue` the defaults. Don't gate on the defaults being present.

## Out of scope

- The dev/prod namespace separation issue (separate ticket).
- Per-account venue customization beyond the default seed.

## Reference

- Caller-side documentation: `code_my_spec_marketing/marketing/daily/2026-05-22.md` (MMS gap #5)
