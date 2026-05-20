# QA Brief — Story 732: MMS Agent connects and reports status

## Tool

web (Vibium for LiveView surfaces) + iex console for channel join assertions

## Auth

Run seeds to get a magic-link URL:

```
cd /Users/johndavenport/Documents/github/market_my_spec
mix run priv/repo/qa_seeds.exs
```

Copy the magic-link URL from the output (e.g. `http://localhost:4007/users/log-in/<token>`) and navigate to it in Vibium to authenticate without email round-trip.

## Seeds

```
cd /Users/johndavenport/Documents/github/market_my_spec
mix run priv/repo/qa_seeds.exs
```

This creates `qa@marketmyspec.test` with a fresh single-use magic-link token. Note the user_id from the output — needed for Presence inspection.

Story-specific setup: pair an agent via the UI at `/agents/pair?state=...&port=51234&name=qa-732` or use the pairing LiveView flow to create a paired agent record before channel join tests.

## Setup Notes

The dev server must be started with explicit PORT:

```
PORT=4007 mix phx.server
```

Or via iex for console access:

```
PORT=4007 iex -S mix phx.server
```

Known issue: ETS tables for Presence and StateStore do not survive hot code reload. If `ArgumentError: ETS table identifier does not refer to an existing ETS table` appears, kill and restart the server (full restart, not reload).

The alternative to a real binary for channel join testing (CRs 6480, 6481, 6485, 6486, 6487, 6488, 6489) is to use `just agent` to run the in-tree agent app, or drive channel joins directly via iex using `Phoenix.ChannelTest`-style patterns against the running server.

For binary-level tests: the Burrito binary is at `burrito_out/market_my_spec_agent_macos_m1`. On first launch without pairing it will log `[Agent.Channel.Client] not paired yet; retrying in 10000ms`.

Auth file structure for manual seeding:
```json
{
  "agent_id": "<uuid>",
  "user_id": <integer>,
  "token": "<plain_token>",
  "server_url": "http://localhost:4007",
  "paired_at": "<iso8601>"
}
```
File must be at `~/.mms-agent/auth.json` with mode 0600.

## What To Test

### Scenario 1 — CR 6480: Valid token joins the channel
- Pair an agent via the Agents pair LiveView (navigate to `/agents/pair?state=test123&port=51234&name=qa-732`, approve, note token and agent_id from redirect URL)
- Via iex or `just agent`, confirm the Channel.Client joins successfully
- In server iex: `MarketMySpec.Agents.Presence.online_agent_ids(<user_id>)` should return a MapSet with the agent_id
- Expected: join succeeds, no error in server logs

### Scenario 2 — CR 6481: Invalid/missing token rejected
- Attempt a channel join with a bogus token (can be done via iex against running server)
- In iex, use Phoenix.ChannelTest pattern: connect to `AgentSocket` with wrong token, attempt join
- Expected: `{:error, %{reason: "unauthorized"}}` returned, no Presence entry created

### Scenario 3 — CR 6482: Online status appears without refresh
- Open Vibium to `/agents` while logged in — agent should show "Offline"
- Start the agent binary or `just agent` (or join channel via iex)
- Without refreshing the page, the agent's status pill should flip to Online
- Look for `data-test="status-online-<agent_id>"` appearing in the DOM
- Take a screenshot showing the Online pill

### Scenario 4 — CR 6483: Offline status appears without refresh
- With agent connected and /agents page open in Vibium showing Online pill
- Kill the agent process or disconnect the channel
- Without refreshing, the Online pill should disappear and "Offline" should appear
- Look for `data-test="status-offline-<agent_id>"` in DOM
- Take a screenshot showing the Offline pill after disconnect

### Scenario 5 — CR 6484: Agents page shows version and last-connect timestamp
- After a successful channel join (agent reports version e.g. `0.3.0`)
- Visit `/agents` in Vibium
- Expected: version string visible (e.g. "v0.3.0" or "0.3.0")
- Expected: last-connect timestamp visible (date format or "just now" / "ago")
- Take a screenshot

### Scenario 6 — CR 6485: Agent joins its own user's topic
- Confirm via iex that after join, `Presence.online_agent_ids(user_id)` returns a set containing the agent_id
- Verify the topic used matches `"agents:<user_id>"` (not a different user)
- Expected: agent appears only in its own user's Presence topic

### Scenario 7 — CR 6486: Cross-user join rejected
- Via iex, attempt to join `"agents:<other_user_id>"` with a valid token belonging to a different user
- Expected: `{:error, %{reason: "unauthorized"}}`
- Verify agent does NOT appear in the other user's Presence

### Scenario 8 — CR 6487: Revoked token refused on rejoin
- Pair an agent, note the token
- On /agents page, click the Revoke button for that agent
- Attempt to join the channel again with the old token
- Expected: join is refused (token_hash no longer matches an active agent)
- Take a screenshot of the Revoked state on /agents

### Scenario 9 — CR 6488: Failed join does not flip status to Online
- Attempt a join with bogus credentials (as in Scenario 2)
- Visit /agents page — agent list should not show any Online pill for the failed join attempt
- Expected: no spurious Online status from a rejected join

### Scenario 10 — CR 6489: Disconnecting one agent doesn't affect others
- Pair two agents for the same user
- Connect both via channel joins
- Verify both show Online on /agents
- Disconnect one agent
- Expected: remaining agent still shows Online, only the disconnected one goes Offline

### Scenario 11 — CR 6490: Never-connected agent shows no last-connect
- Find or create a paired agent that has never joined a channel
- Visit /agents
- Expected: agent shows "· never connected" (no timestamp)
- The `a.last_seen_at` field should be nil for this agent
- Take a screenshot confirming the "never connected" label

## Result Path

`.code_my_spec/qa/732/result.md`
