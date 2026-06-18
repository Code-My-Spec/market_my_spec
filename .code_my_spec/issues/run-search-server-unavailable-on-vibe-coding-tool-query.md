# `run_search` returns `-32603 Server unavailable` consistently for one specific query string

**Reporter:** Marketing operator via MMS MCP, 2026-06-08
**Severity:** Medium — single search recipe unusable; other recipes work
**Touchpoint area:** `lib/market_my_spec/mcp_servers/engagements/tools/run_search.ex` + `lib/market_my_spec/engagements/saved_searches_repository.ex` (`fan_out_search/3`) + `lib/market_my_spec/engagements/search.ex` (`search/3`)

## Summary

`mcp__claude_ai_Mms__run_search` consistently returns the following error for one specific saved search (id 18) — reproduced **4 separate times** across a single MCP session. All other saved searches in the same session, hitting overlapping venue sets, succeed.

```json
{
  "error": {
    "code": -32603,
    "data": { "message": "Server unavailable" },
    "message": "Internal error"
  }
}
```

The `-32603` is the JSON-RPC "Internal error" code. The `data.message` says "Server unavailable" but the search is not hitting an HTTP endpoint that an operator can see — Reddit RSS feeds for the venues in this search return 200 fine when other queries hit the same venues.

## Failing query (saved search id 18)

**Name:** `BO — Vibe-coded app broken, need rebuild`
**Query string:** `lovable bolt cursor replit app broken doesn't work need help rebuild`
**Venues:** `vibecoding` (id 14), `saas` (19), `microsaas` (22), `SideProject` (20), `indiehackers` (21)

## Comparison — what works vs what fails (same session, same account)

| Search id | Query | Venue count | Result |
|---|---|---|---|
| 13 | `app website broken developer ghosted need help` | 10 | ✅ 229 candidates |
| 14 | `custom software application tool business workflow operations` | 8 | ✅ 200 candidates |
| 15 | `tool software workflow author publishing book platform` | 4 | ✅ 100 candidates |
| 16 | `AI built app no code platform doesn't work problems` | 8 | ✅ one run, ❌ another (intermittent — 1 success / 1 failure) |
| 17 | `looking for developer take over project hire build app` | 7 | ✅ ~190 candidates |
| **18** | **`lovable bolt cursor replit app broken doesn't work need help rebuild`** | **5** | **❌ 4 of 4 attempts — "Server unavailable"** |
| 19 | `need agency freelancer custom build app website project hire` | 6 | ✅ ~150 candidates |
| 20 | `custom software developer build app website business workflow hire` | 13 | ✅ ~250 candidates |
| 21 | `scheduling dispatch job tracking software customer portal invoicing` | 11 | ✅ ~220 candidates |

**Hypothesis surface from this table:**
- It's not venue-set: search 18's venue set is a strict subset of search 16's (which sometimes works).
- It's not the apostrophe in `doesn't`: search 16 has the same word and runs (intermittently).
- It's not response payload size: 18 fails before any payload returns; successful runs return 100-250KB payloads without issue.
- It's not the venue count: search 18 has only 5 venues (smaller than the others).
- **The likely culprit is the specific token set `lovable bolt cursor replit`** — either (a) Reddit's per-subreddit search.rss endpoint returns a non-200 response or hangs on this multi-tool-name query, OR (b) the query produces a result row that fails `persist_and_enrich/2` at the DB layer (e.g. an entry the changeset rejects), and the error isn't being caught.

## What `run_search.ex` actually handles

`lib/market_my_spec/mcp_servers/engagements/tools/run_search.ex:28-35` only handles two return shapes from `Engagements.run_saved_search/2`:

```elixir
case Engagements.run_saved_search(scope, search_id) do
  {:ok, %{candidates: candidates, failures: failures}} ->
    payload = %{candidates: candidates, failures: encode_failures(failures)}
    {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

  {:error, :not_found} ->
    {:reply, Response.tool() |> Response.error("Saved search not found: #{search_id}"), frame}
end
```

Any **raised exception or non-matching return value** from `Engagements.run_saved_search/2` propagates up to the MCP transport and surfaces as `-32603 Server unavailable`. That's the failure mode the operator sees.

## Where the raise likely originates

Tracing the call:

1. `Engagements.run_saved_search/2` → `SavedSearchesRepository.run_saved_search/2` (lib/market_my_spec/engagements/saved_searches_repository.ex:177)
2. → `fan_out_search/3` (saved_searches_repository.ex:279) — `Task.async_stream` per venue with 35s timeout, handles `{:exit, reason}` gracefully
3. → `Search.search/3` per venue (lib/market_my_spec/engagements/search.ex:67) — does its OWN inner `Task.async_stream` (15s timeout) → `search_venue/4` → `adapter.search/3` (with `rescue`)
4. → `persist_and_enrich(candidates, scope)` at search.ex:83

Each fan-out layer catches `{:exit, ...}` and adapter exceptions. The two-layer fan-out should make this very robust to venue-level failures.

**Two paths I'd investigate first:**

1. **`persist_and_enrich/2` at `engagements/search.ex:222`** — does it raise on any specific candidate shape? If a Reddit result for this query has an unusual character (emoji, control character, very long title, etc.) that breaks the Thread changeset or its DB insert, `persist_and_enrich` would raise unhandled.
2. **`Jason.encode!(payload)` at `run_search.ex:31`** — if any candidate field is non-JSON-serializable (e.g., a `NaiveDateTime` that somehow ends up as an unencodable struct, or a tuple), `Jason.encode!` raises. Wrap with `Jason.encode/1` and handle the `{:error, ...}` shape.

## Reproduction steps

1. Connect to MMS as account that owns saved search id 18 (name: `BO — Vibe-coded app broken, need rebuild`).
2. Call `mcp__claude_ai_Mms__run_search` with `search_id: 18`.
3. Observe: `-32603 Server unavailable`.
4. Repeat at any cadence — failure is consistent.

If saved search id 18 isn't reachable (cross-account), create one with the failing query and venue set listed above, then run it.

## Suggested fix path

1. Wrap `Engagements.run_saved_search/2` call in `run_search.ex` with a catch-all clause:
   ```elixir
   rescue
     error ->
       Logger.error("run_saved_search raised: #{inspect(error)}\n#{Exception.format_stacktrace()}")
       {:reply, Response.tool() |> Response.error("Search failed: #{Exception.message(error)}"), frame}
   ```
   This converts the silent `-32603` into an actionable MCP error message that names the failure.
2. With the logged stacktrace from step 1, identify the raising callsite (almost certainly inside `persist_and_enrich/2` or `Jason.encode!/1`).
3. Add a targeted reproduction test that runs the failing query against the venue set and asserts the expected behavior (either success-with-empty-results, or a clean `:error` tuple — not a raise).

## Side note — `add_venue` integer-weight rejection

While setting up venues for this scan I hit a separate validation quirk: `mcp__claude_ai_Mms__add_venue` rejects requests where `weight` is sent as an **integer** (`1`) with `Invalid params (-32602)`. The same call succeeds when `weight` is sent as a **float** (`0.9` or `1.0`) or when `weight` is omitted (defaults to `1.0`). This affected ~5 of my first venue-add attempts and was easy to work around once spotted, but worth fixing — Peri/changeset coercion should accept integer → float for a `:float` field, and if not, the error message should name the field instead of returning a generic JSON-RPC error.

Reproducible at `lib/market_my_spec/mcp_servers/engagements/tools/add_venue.ex` schema → `field :weight, :float`.
