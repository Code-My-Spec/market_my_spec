# MarketMySpecWeb.AgentLive

Agents page — paired binary lifecycle UX. Renders the agent pairing approval screen (consent + completion confirmation) called from the binary's first run, and the agents list (status, binary version, last-seen, revoke action) used to verify a binary is online before triggering Reddit operations. Reached from main nav; consumed by binaries' install/pair flow and by users diagnosing why a Reddit op failed offline.

## Type

live_context

## Dependencies

- MarketMySpec.Agents
- MarketMySpec.Users
