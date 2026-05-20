# MarketMySpecWeb.AgentLive.Index

Agents page index. Lists the current user's paired agents (one user can own multiple binaries across machines; the list is user-scoped, not account-scoped) with status badge (online/offline driven by Agents.Presence diffs over PubSub), binary version, last_seen_at, and a revoke action. Empty state instructs the user to install + pair via Homebrew (brew install codemyspec/tap/mms-agent → mms-agent pair). Links to AgentLive.Pair as the in-app entry point for the pairing approval screen reached from a binary's browser handoff.

## Type

liveview
