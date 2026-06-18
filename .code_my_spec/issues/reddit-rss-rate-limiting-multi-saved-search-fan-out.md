# Reddit RSS rate limiting kills multi-saved-search fan-out

**Reporter:** Marketing operator via MMS MCP, 2026-06-12
**Severity:** Medium — interrupts daily social-engagement scanning when 4+ saved searches run in parallel
**Touchpoint area:** `lib/market_my_spec/engagements/source/reddit.ex` (search/2) + `lib/market_my_spec/engagements/search.ex` (fan_out/4) + `lib/market_my_spec/engagements/saved_searches_repository.ex` (fan_out_search/3)

## Summary

Running 4–5 MMS saved searches in parallel against overlapping Reddit venue sets trips Reddit's RSS rate limit (HTTP 429). Affected venues return `{:error, {:http_status, 429}}` from `Reddit.search/3`, which surfaces in the caller's `failures` list as:

```json
{"reason": "Rate limited (HTTP 429 Too Many Requests)", "source": "reddit", "venue_identifier": "ClaudeAI"}
```

Every subsequent saved search that fans out to those same venues returns **zero candidates** until the throttle clears (~2–3 minutes empirically). The first search of a batch usually completes; later ones are dead-on-arrival.

## Reproduction (2026-06-12, observed)

Invoked `mcp__claude_ai_Mms__run_search` for saved searches 1, 3, 5, 6, 8 in a single parallel batch. Each search hits 4–10 Reddit venues, with significant overlap (most include r/ClaudeAI, r/ChatGPTCoding, r/vibecoding, r/elixir).

Result:
- Search 1: partial success (raced first). Returned ChatGPTCoding + ElixirForum candidates; ClaudeAI / elixir / vibecoding marked 429.
- Searches 3, 5, 6, 8: **zero candidates**, every Reddit venue marked 429.
- ElixirForum (separate rate-limit pool) succeeded in every call.

Throttle persisted ~2–3 minutes before subsequent calls succeeded again.

## Why this matters

The MMS daily-engagement workflow involves running 3–5 saved searches sequentially to surface fresh threads across the engineer rotation. The current behavior:

1. Operator runs saved searches in parallel (the natural thing to do — they're independent recipes).
2. First search succeeds, populates partial UI.
3. Remaining searches return empty (false-negative — looks like "no fresh threads," is actually "rate-limited").
4. Operator either retries (compounds the problem) or moves to ElixirForum-only (works because separate pool), but loses Reddit visibility for that session.

The current adapter does the right thing — `{:error, {:http_status, 429}}` is correctly handled, formatted as "Rate limited (HTTP 429 Too Many Requests)", and degrades gracefully. **The gap is at the orchestration layer**: there's no rate-limiting, request-coalescing, or backoff between concurrent fan-outs.

## What Reddit's RSS endpoint actually allows

Reddit's public RSS (`/r/{sub}/search.rss`) for anonymous unauthenticated requests has empirical rate limits around 60 requests/min per IP, lower per-source over short windows. Each MMS saved-search invocation produces N concurrent requests (one per venue) via `Task.async_stream` at engagements/search.ex:95. Running 5 searches × 6 venues = 30 simultaneous requests from a single IP — well over Reddit's tolerance for burst.

## Suggested fix paths

### Option 1: Server-side token bucket per source

A GenServer that holds a per-source token bucket (`Reddit`, `ElixirForum` as separate buckets since they have separate rate-limit pools per observation). Adapter `search/3` calls go through the bucket:

```elixir
defmodule MarketMySpec.Engagements.RateLimiter do
  use GenServer
  # Bucket: 30 tokens, refills 1 token / 2s for reddit
  # Bucket: 100 tokens, refills 5 tokens / 1s for elixirforum
end

# In source/reddit.ex
def search(venue, query, opts \\ []) do
  case RateLimiter.acquire(:reddit, 5_000) do
    :ok -> # existing Req.get logic
    {:error, :timeout} -> {:error, :rate_limit_pending}
  end
end
```

Pros: simple, scoped, surface-able. Cons: doesn't handle the case where a single saved-search recipe has many venues — would need to queue, slowing one search rather than failing many.

### Option 2: Coalesce concurrent venue requests within a window

If two saved searches both hit r/ClaudeAI within 30 seconds, fetch the RSS feed once and share the result. The Reddit RSS feed for a query+sub is stable on the order of 1-2 minute granularity, so coalescing identical (venue, query) calls within a 30-second window would dramatically reduce request count.

Pros: works without the operator changing behavior. Cons: more complex; needs a request cache keyed by (venue, query, cursor) with a short TTL.

### Option 3: Respect `Retry-After` and backoff

Reddit's 429 response includes a `Retry-After` header. The current code drops it — `Req.get/2` returns `{:ok, %Req.Response{status: 429}}` which our adapter maps to `{:error, {:http_status, 429}}` and surfaces as a failure without using the retry hint. Could:

1. Parse `Retry-After` from the response.
2. On 429, sleep (or schedule a retry) for that duration up to a cap.
3. Re-invoke once. If still 429, give up.

Pros: minimal code change, uses server-provided signal. Cons: introduces latency into the synchronous saved-search path; not a real fix for the "5 searches in parallel" case where you'd still cluster retries.

### Option 4: OAuth path with authenticated rate limits

Reddit's OAuth-authenticated rate limit is ~5000 req/min per app, vs ~60 req/min anonymous. The MMS server is already paired in some flows; adding an authenticated-Reddit path would 10–100× the headroom.

Pros: solves the problem at the source. Cons: requires Reddit app registration, OAuth token refresh, surfacing of auth errors. Much more code than the in-memory rate-limiter options.

## Recommended path

**Option 1 (token bucket) + Option 3 (Retry-After respect), combined.** The bucket prevents the burst that triggers 429 in the first place. Retry-After handling salvages requests that slip through anyway. Both are scoped to the adapter layer (no API changes upstream) and ship in <200 lines.

Option 2 (coalescing) is a nice-to-have later for query-overlap optimization, but isn't strictly necessary for fixing the throttle problem.

Option 4 (OAuth) is the right long-term move but is over-engineered for the current workload.

## Adjacent finding

When the rate-limit failures surface, the operator-facing message from `run_search` is currently just the failures list. Could be more helpful to surface a `notice` like "3 of 6 venues throttled — wait ~2-3 minutes and re-run" so the operator doesn't interpret zero candidates as "no fresh threads." The notice infrastructure already exists at `engagements/search.ex:60` (the `:notices` field in the result envelope).

## Operator workaround for now

Per [[feedback_mms_search_throttle.md]] in the operator memory:
- Run searches serially, not in parallel.
- OR batch by non-overlapping venue sets (e.g., one batch hitting ClaudeAI+vibecoding, another hitting programming+AskProgramming).
- ElixirForum-only saved searches always work — separate rate-limit pool.
- If throttled, wait 2–3 minutes and retry.
