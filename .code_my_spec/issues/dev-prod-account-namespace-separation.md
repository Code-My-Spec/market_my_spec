# Dev/prod accounts have separate venue + search ID namespaces; touchpoints orphaned on env switch

Filed 2026-05-22 from MMS MCP usage during the CodeMySpec marketing cycle.

## Problem

Dev and prod MMS deployments use separate account scoping. When the MCP repoints from dev to prod (e.g. via `/mcp` reconnect), the operator loses access to:

- Saved searches by ID — dev's search ID 13 is not the same as prod's search ID 13
- Venues by ID — dev's venue ID 5 (`reddit:elixir`) is not the same as prod's
- Touchpoints by ID — staged touchpoints on dev are invisible on prod

The session today staged 5 Reddit touchpoints on dev MMS in the morning (Matt's 1tj7lyc, Edward's 1tj80gn, etc.). Mid-session the operator switched the MCP to prod. The dev touchpoints became unreachable — same source thread IDs, but the MMS thread UUIDs are different per account, and there's no "migrate to prod" path.

Net effect: 5 polished, Vale-linted touchpoints were lost to env switch. Had to re-stage all of them on prod from scratch.

## Why it matters

Operators switching between dev (for testing) and prod (for real ops) is a normal workflow. Today's session was probably the worst case (full session of work on dev, then switch to prod), but even a small mid-session switch can orphan work without warning.

## Two hypotheses on the right shape

1. **Migrate touchpoints across accounts** — add a `copy_touchpoint(touchpoint_id, target_account)` tool. Operator-driven.
2. **Make env switching opaque to the operator** — single account namespace, dev and prod are just different deployment targets of the same data. Bigger change; may not match how the server is architected.
3. **Make env switching loudly visible** — when the MCP reconnects to a different account, show the operator a "you're on a different account; the X touchpoints you staged are not visible here" warning. Low effort, high signal.

Recommend (3) for the short term and (1) for the medium term.

## Acceptance criteria

1. When `/mcp` reconnects and the underlying account changes, the next tool call returns a notice in the response envelope (`notices` field): "Account changed from <dev> to <prod>. Touchpoints from prior account are not visible in this session."
2. Add a `copy_touchpoint` MCP tool that takes a touchpoint ID and a target account, and copies the full record (synopsis on parent Thread, angle, polished_body, utm fields) to the target account. Returns the new touchpoint_id.
3. (Optional, follow-up) Add a `list_touchpoints_across_accounts` admin tool so an operator can find their orphaned work.

## Out of scope

- Re-architecting the account namespace.
- Multi-account collaboration (an operator on multiple accounts simultaneously).

## Reference

- Caller-side documentation: `code_my_spec_marketing/marketing/daily/2026-05-22.md` (MMS gap #6)
