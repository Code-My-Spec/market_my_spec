# QA Brief — Story 733: Reddit operations route through agent HTTP transport

## Tool

iex (interactive BEAM session via `just server`) — all 10 ACs are exercised through
direct Elixir calls against the running OTP application. The MCP tool
`SearchEngagements.execute/2` is invoked in-process; `Dispatcher.dispatch_http/3`
is called directly; PubSub subscriptions are set up in the iex REPL.

## Auth

Run seeds to get a QA user and magic-link token:

```
cd /Users/johndavenport/Documents/github/market_my_spec
mix run priv/repo/qa_seeds.exs
```

For pairing flows that require a browser session, start the server with an attached
REPL (`just server` or `PORT=4007 iex -S mix phx.server`) and use the magic-link
URL printed by the seed script to authenticate a `conn` inside the iex session.

All Dispatcher and SearchEngagements calls are in-process — no HTTP auth required
for the test calls themselves.

## Seeds

```
cd /Users/johndavenport/Documents/github/market_my_spec
mix run priv/repo/qa_seeds.exs
```

For agent-pairing steps: use `MarketMySpec.UsersFixtures.account_scoped_user_fixture/0`
and `MarketMySpec.UsersFixtures.generate_user_magic_link_token/1` in iex to create
test users without touching the QA seed user.

For channel joins: use `MarketMySpec.AgentsTestHelpers.join_agent_channel/4` directly
in iex — it handles the Phoenix.ChannelTest join, waits for Presence, and returns the
channel socket.

## Setup Notes

The BDD spex suite for this story passes 10/10. All ACs are implemented. QA exercises
the live surface (running BEAM via iex) rather than the spex test harness to verify
behavior in the dev runtime.

**Hot-reload ETS issue (same as story 732):** Restart the server fully at session start
(`just server` in a fresh terminal) to avoid stale ETS state from hot-reload sessions.

**Server port:** Always start with `PORT=4007 iex -S mix phx.server` (or `just server`)
— `envs/dev.env` PORT is not auto-loaded by Dotenvy in dev startup.

**Timeout shortcut:** For AC 6496 (timeout) use `timeout: 1_000` (1s) in
`Dispatcher.dispatch_http/3` opts to avoid waiting 30s.

**AC 6497 (429 + Retry-After):** Cannot be elicited from real Reddit in a controlled
way without a rate-limiting stub. This AC is verified by the BDD spex which mocks the
transport; the live QA will document it as covered by spex and not reproducible without
a stub at this scale.

## What To Test

### AC 6491 — Reddit search dispatches through user's online agent

1. In `iex -S mix phx.server` (port 4007), create a user+scope+venue:
   ```elixir
   scope = MarketMySpec.UsersFixtures.account_scoped_user_fixture()
   user = scope.user
   MarketMySpec.EngagementsFixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})
   ```
2. Pair and join an agent channel:
   ```elixir
   {tok, _} = MarketMySpec.UsersFixtures.generate_user_magic_link_token(user)
   conn = Phoenix.ConnTest.build_conn() |> Plug.Test.init_test_session(%{})
   conn = Phoenix.ConnTest.post(conn, "/users/log-in", %{"user" => %{"token" => tok}})
   {agent, token} = MarketMySpec.AgentsTestHelpers.pair_via_ui(conn, user, name: "mac")
   {:ok, _, channel} = MarketMySpec.AgentsTestHelpers.join_agent_channel(user.id, agent.id, token)
   ```
3. Subscribe to agent topic and call SearchEngagements in a spawned process:
   ```elixir
   MarketMySpec.AgentsTestHelpers.subscribe_to_agent_topic(user.id)
   frame = %{assigns: %{current_scope: scope}, context: %{session_id: "qa"}}
   spawn(fn -> send(self(), {:result, MarketMySpec.McpServers.Engagements.Tools.SearchEngagements.execute(%{query: "elixir"}, frame)}) end)
   ```
4. Capture the http_request envelope and respond with a stub Reddit listing.
5. Confirm the tool returns `{:reply, response, frame}` and the envelope URL contains `oauth.reddit.com`.

Expected: envelope contains `"url"` with `oauth.reddit.com`, tool reply arrives.

### AC 6492 — Dispatch picks most recently connected agent

1. Create user+scope+venue, pair TWO agents (agent_a, agent_b).
2. Join agent_a's channel, sleep 1.1s, join agent_b's channel.
3. Subscribe to agent topic, call SearchEngagements, observe http_request envelope.
4. Assert `envelope["agent_id"] == agent_b.id`.

Expected: the envelope targets agent_b (most recently connected).

### AC 6493 — Allowlisted host is accepted

1. Call `MarketMySpec.Agents.HostAllowlist.allowed?/1` for:
   - `"https://oauth.reddit.com/r/elixir.json"` → expect `true`
   - `"https://www.reddit.com/r/elixir/search.json"` → expect `true`
   - `"https://api.reddit.com/r/elixir"` → expect `true` (subdomain)

Expected: all reddit.com and oauth.reddit.com URLs pass the allowlist.

### AC 6494 — Non-allowlisted host refused before dispatch

1. Create user, subscribe to agent topic.
2. Call `MarketMySpec.Agents.Dispatcher.dispatch_http(user, %{method: :get, url: "https://example.com/not-reddit", headers: [], body: ""})`.
3. Assert result is `{:error, :host_not_allowed}`.
4. Assert no `http_request` broadcast arrives within 200ms.

Expected: `{:error, :host_not_allowed}` immediately, no PubSub broadcast.

### AC 6495 — Response within 30s returned to caller

Covered implicitly by AC 6491 happy path (tool returns response within the test window).
Confirm the tool returns a `{:reply, _response, _frame}` tuple with `candidates`, `failures`, and `notices` keys in the JSON payload.

### AC 6496 — No response within 30s returns timeout error

1. Create user, pair agent, join channel (agent is "silent" — will receive but not respond).
2. Call `Dispatcher.dispatch_http(user, %{method: :get, url: "https://oauth.reddit.com/r/elixir.json", headers: [], body: ""}, timeout: 1_000)`.
3. Assert result is `{:error, :timeout}` after ~1s.

Expected: `{:error, :timeout}`.

### AC 6497 — 429 + Retry-After preserved through agent transport

Cannot be elicited from real Reddit without a rate-limiting stub. This AC is covered
by the BDD spex (criterion_6497_spex.exs). Document as: "verified by BDD spex;
not reproducible in live QA without a network-layer 429 stub."

### AC 6498 — ElixirForum HTTP bypasses the agent

1. Create user+scope, add an ElixirForum venue (source: :elixirforum, identifier: "elixir").
2. Join an agent channel for the user so an agent IS online.
3. Subscribe to `"agents:<user_id>"` on PubSub.
4. Call SearchEngagements for the ElixirForum venue.
5. Assert no `http_request` broadcast arrives within 300ms.

Expected: tool returns ElixirForum candidates; no agent broadcast fires.

### AC 6499 — No online agent surfaces user-facing notice with /agents link

1. Create user+scope+reddit venue but do NOT pair or join any agent.
2. Call SearchEngagements.execute with the scope.
3. Parse the JSON response and inspect the `notices` array.
4. Assert at least one notice contains the string "/agents".

Expected: `notices` contains a string like "Pair or start an agent at /agents".

### AC 6500 — Disconnect mid-flight returns cancellation error before timeout

1. Create user, pair agent, join channel, subscribe to agent topic.
2. Spawn a Task that calls `Dispatcher.dispatch_http(user, %{method: :get, url: "https://oauth.reddit.com/r/elixir.json", headers: [], body: ""})`.
3. Wait for the `http_request` envelope to arrive (confirms dispatcher is in-flight).
4. Kill the channel socket (AgentsTestHelpers.kill_channel/1).
5. Task.await the dispatcher task — assert result is `{:error, :agent_disconnected}` in well under 30s.

Expected: `{:error, :agent_disconnected}`, arrives in <5s.

## Result Path

`.code_my_spec/qa/733/result.md`
