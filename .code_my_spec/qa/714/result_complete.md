# Qa Result

## Status

pass

## Scenarios

### Scenario 1 — Both sources return candidates (criterion 6283)

pass

Ran: `MIX_ENV=test mix spex test/spex/714.../criterion_6283_...exs`

Result: 1 test, 0 failures. Response payload includes candidates from both `"reddit"` and `"elixirforum"` sources after fixes applied (see Issues section).

### Scenario 2 — Shape parity (criterion 6284)

pass

Result: 1 test, 0 failures. Both candidate types have the canonical keys: `thread_id, title, source, url, score, reply_count, recency, snippet, engagement`. Key sets are identical between Reddit and ElixirForum candidates.

### Scenario 3 — Failure isolation (criterion 6285)

pass

Result: 1 test, 0 failures. When Reddit returns a non-200 status (cassette), ElixirForum candidates still appear in the response and a Reddit failure entry is present in `failures`.

### Scenario 4 — All sources fail (criterion 6286)

pass

Result: 1 test, 0 failures. Empty candidates list, both Reddit and ElixirForum failure entries present with identifiers and human-readable reasons.

### Scenario 5 — Cross-source interleave ordering (criterion 6287)

pass

Result: 1 test, 0 failures. Results are interleaved by venue weight descending — first three positions cover both sources.

### Scenario 6 — Behaviour dispatch (criterion 6390)

pass

Result: 1 test, 0 failures. Both adapters declare `@behaviour MarketMySpec.Engagements.Source`. One search call returns candidates from both sources, confirming dispatch routes by `venue.source`.

### Scenario 7 — validate_venue (criterion 6391)

pass

Result: 1 test, 0 failures. Pure validation — no HTTP. Valid slugs (`phoenix`, `elixir:phoenix-1-7`, `questions`) return `:ok`; malformed identifiers (empty string, spaces, slashes, multiple colons, bare colon prefix/suffix, full URLs) return `{:error, _}`.

### Scenario 8 — Discourse normalization (criterion 6392)

pass

Result: 1 test, 0 failures. Forum candidate has non-empty `title`, `source=elixirforum`, URL containing `elixirforum.com`, integer `reply_count`, non-nil `recency`, binary `snippet`.

### Scenario 9 — Identical key sets (criterion 6393)

pass

Result: 1 test, 0 failures. Reddit and ElixirForum candidates in a single response have identical sorted key sets.

### Scenario 10 — Reddit 429 + ElixirForum 200 (criterion 6394)

pass

Result: 1 test, 0 failures. ElixirForum thread is present in candidates, Reddit failure entry carries reason mentioning rate limit.

### Scenario 11 — All venues 5xx (criterion 6395)

pass

Result: 1 test, 0 failures. All 4 venues fail; candidates list is empty; 4 per-venue failure entries present with distinct identifiers.

### Scenario 12 — Weighted cross-source ordering (criterion 6396)

pass

Result: 1 test, 0 failures. High-weight ElixirForum candidate ranks ahead of low-weight Reddit candidate.

### Scenario 13 — Failure entry shape (criterion 6397)

pass

Result: 1 test, 0 failures. Each failure entry carries `source`, `venue_identifier`, and `reason` as required.

## Evidence

All 13 spex run via `MIX_ENV=test mix spex <path>`. Final run: 13 tests, 0 failures.

Full test suite: 171 tests, 0 failures (5 excluded). No compiler warnings.

## Issues

### Thread.changeset/2 required fetched_at but upsert_from_search did not supply it — all search candidates silently dropped

#### Severity
CRITICAL

#### Description
`Thread.changeset/2` had `:fetched_at` in `@required_fields` while migration `20260516092000_make_thread_fetched_at_nullable.exs` made the column nullable. `ThreadsRepository.upsert_from_search/3` does not provide `fetched_at` (intentionally — it is set by deep-read flows in story 706, not at search time). This caused every search-time upsert to fail changeset validation, and `Search.persist_and_enrich/2` silently dropped all candidates.

Fixed by removing `:fetched_at` from `@required_fields` in `lib/market_my_spec/engagements/thread.ex` and moving it to `@optional_fields`. Updated `thread_test.exs` to replace the "requires fetched_at" test with "fetched_at is optional".

### Cassettes missing categories.json interaction — ElixirForum adapter fails cold

#### Severity
HIGH

#### Scope
QA

#### Description
The ElixirForum adapter resolves a category slug to a numeric Discourse category ID by fetching `/categories.json` and caching the result in `:persistent_term`. Several cassettes were recorded with the `:persistent_term` cache already warm from a prior cassette run, so the `categories.json` request was never captured. When these spex ran with a cold cache (e.g., isolated runs), the adapter tried to fetch `categories.json`, found no matching cassette interaction, and returned `{:error, _}` — causing ElixirForum candidates to be absent.

Affected cassettes: `crit_6284_shape_parity`, `crit_6285_failure_isolation`, `crit_6287_interleave`, `crit_6390_behaviour_dispatch`, `crit_6393_key_set_parity`, `crit_6394_reddit_429`, `crit_6396_weighted_ordering`.

Fixed by prepending the `categories.json` interaction (copied from `crit_6283_mixed_sources.json`) to each affected cassette.

### Unused variable in Search.do_interleave/2 causes compiler warning

#### Severity
LOW

#### Description
`Search.do_interleave/2` in `lib/market_my_spec/engagements/search.ex` assigned `remaining = Enum.reject(tails, &(&1 == []))` but never used the variable — the recursive call uses `non_empty_tails = tails` instead. Fixed by prefixing with `_`: `_remaining = Enum.reject(...)`.
