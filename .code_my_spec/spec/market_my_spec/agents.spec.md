# MarketMySpec.Agents

User-paired local agent binaries. Owns Agent records (per-user paired binaries with encrypted long-lived tokens), Phoenix.Presence tracking of online agents, a Dispatcher that broadcasts HTTP request envelopes to a target agent over its Phoenix channel and awaits responses with a 30s timeout, host-allowlist enforcement (reddit.com, oauth.reddit.com), and the Pairing flow that turns a user's in-browser consent into a stored Agent + issued token. The dispatch path is a single Phoenix-channel route — Req+ReqCassette covers HTTP recording on the binary side, so no transport-stub indirection is needed here.

## Type

context

## Dependencies

- MarketMySpec.Users
- MarketMySpecAgent
