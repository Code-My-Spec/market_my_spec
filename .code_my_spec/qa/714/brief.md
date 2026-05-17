# Qa Story Brief

## Tool

curl (MCP JSON-RPC surface) and direct spex execution via `mix spex` for unit/integration coverage; no LiveView interaction required for this story.

## Auth

This story tests the MCP tool layer (`SearchEngagements.execute/2`) and the source adapters (`ElixirForum`, `Reddit`) directly in the test environment. No authenticated HTTP session is required. The spex call tool modules directly with a synthesized Anubis frame carrying a `current_scope`.

Run seed script to confirm the test DB is migrated before running spex:

```
cd /Users/johndavenport/Documents/github/market_my_spec
MIX_ENV=test mix ecto.migrate
```

## Seeds

No seed script required. The spex use `MarketMySpecSpex.Fixtures.account_scoped_user_fixture/0` and `venue_fixture/2` to create in-memory test data within the Ecto sandbox. HTTP is intercepted by ReqCassette using pre-recorded cassettes in `test/cassettes/elixirforum/`.

## What To Test

### Scenario 1 — Both sources return candidates (criterion 6283)

Run:
```
MIX_ENV=test mix spex test/spex/714_add_elixirforum_as_a_second_engagement_source/criterion_6283_results_sourced_from_reddit_and_elixirforum_behind_common_source_behaviour_spex.exs
```

Expected: 1 test, 0 failures. Response payload includes candidates from both `"reddit"` and `"elixirforum"` sources.

### Scenario 2 — Shape parity (criterion 6284)

Run:
```
MIX_ENV=test mix spex test/spex/714_add_elixirforum_as_a_second_engagement_source/criterion_6284_reddit_and_elixirforum_candidates_share_the_same_shape_spex.exs
```

Expected: 1 test, 0 failures. Both candidate types have the canonical keys: `thread_id, title, source, url, score, reply_count, recency, snippet`.

### Scenario 3 — Failure isolation (criterion 6285)

Run:
```
MIX_ENV=test mix spex test/spex/714_add_elixirforum_as_a_second_engagement_source/criterion_6285_one_source_failing_does_not_poison_the_other_sources_results_spex.exs
```

Expected: 1 test, 0 failures. When Reddit fails (cassette returns non-200), ElixirForum candidates still appear and a Reddit failure entry appears in `failures`.

### Scenario 4 — All sources fail (criterion 6286)

Run:
```
MIX_ENV=test mix spex test/spex/714_add_elixirforum_as_a_second_engagement_source/criterion_6286_all_sources_failing_returns_empty_candidate_list_with_per_source_failure_entries_spex.exs
```

Expected: 1 test, 0 failures. Empty candidates list, both Reddit and ElixirForum failure entries present.

### Scenario 5 — Cross-source interleave ordering (criterion 6287)

Run:
```
MIX_ENV=test mix spex test/spex/714_add_elixirforum_as_a_second_engagement_source/criterion_6287_cross_source_ordering_interleaves_per_source_ranked_lists_spex.exs
```

Expected: 1 test, 0 failures. Results are interleaved by venue weight descending.

### Scenario 6 — Behaviour dispatch (criterion 6390)

Run:
```
MIX_ENV=test mix spex test/spex/714_add_elixirforum_as_a_second_engagement_source/criterion_6390_both_adapter_modules_implement_source_behaviour_orchestrator_dispatches_by_venue_source_spex.exs
```

Expected: 1 test, 0 failures. Both adapters implement the `Source` behaviour; orchestrator dispatches by `venue.source`.

### Scenario 7 — validate_venue (criterion 6391)

Run:
```
MIX_ENV=test mix spex test/spex/714_add_elixirforum_as_a_second_engagement_source/criterion_6391_validate_venue_accepts_category_slug_and_category_slug_tag_rejects_malformed_spex.exs
```

Expected: 1 test, 0 failures. Pure validation — no HTTP. Valid slugs (`phoenix`, `elixir:phoenix-1-7`) return `:ok`; malformed identifiers return `{:error, _}`.

### Scenario 8 — Discourse normalization (criterion 6392)

Run:
```
MIX_ENV=test mix spex test/spex/714_add_elixirforum_as_a_second_engagement_source/criterion_6392_discourse_latest_json_normalizes_to_thread_rows_with_the_canonical_field_set_spex.exs
```

Expected: 1 test, 0 failures. Forum candidate has non-empty `title`, `source=elixirforum`, URL containing `elixirforum.com`, integer `reply_count`, non-nil `recency`, binary `snippet`.

### Scenario 9 — Identical key sets (criterion 6393)

Run:
```
MIX_ENV=test mix spex test/spex/714_add_elixirforum_as_a_second_engagement_source/criterion_6393_reddit_and_elixirforum_candidates_in_one_response_have_identical_key_sets_spex.exs
```

Expected: 1 test, 0 failures.

### Scenario 10 — Reddit 429 + ElixirForum 200 (criterion 6394)

Run:
```
MIX_ENV=test mix spex test/spex/714_add_elixirforum_as_a_second_engagement_source/criterion_6394_reddit_429_plus_elixirforum_200_response_has_forum_thread_and_reddit_failure_entry_spex.exs
```

Expected: 1 test, 0 failures. ElixirForum thread present, Reddit failure entry with reason mentioning rate limit.

### Scenario 11 — All venues 5xx (criterion 6395)

Run:
```
MIX_ENV=test mix spex test/spex/714_add_elixirforum_as_a_second_engagement_source/criterion_6395_every_venue_across_every_source_5xx_empty_candidates_plus_per_venue_failure_entries_spex.exs
```

Expected: 1 test, 0 failures.

### Scenario 12 — Weighted cross-source ordering (criterion 6396)

Run:
```
MIX_ENV=test mix spex test/spex/714_add_elixirforum_as_a_second_engagement_source/criterion_6396_high_weight_elixirforum_candidate_outranks_low_weight_reddit_candidate_with_same_per_source_signal_spex.exs
```

Expected: 1 test, 0 failures.

### Scenario 13 — Failure entry shape (criterion 6397)

Run:
```
MIX_ENV=test mix spex test/spex/714_add_elixirforum_as_a_second_engagement_source/criterion_6397_failure_entries_carry_source_venue_identifier_and_a_human_readable_reason_spex.exs
```

Expected: 1 test, 0 failures. Each failure entry has `source`, `venue_identifier`, and `reason` fields.

## Result Path

`.code_my_spec/qa/714/result.md`

## Setup Notes

All 13 BDD spex were reported as green in the commit message (263cb9b), but preliminary investigation shows some spex are currently failing. The `Thread.changeset/2` has `fetched_at` in `@required_fields` but `ThreadsRepository.upsert_from_search/3` does not supply it, causing changeset validation to fail and silently dropping all candidates in `persist_and_enrich/2`. Run each spex individually and record actual pass/fail status in the result.

HTTP interactions are served from cassettes in `test/cassettes/elixirforum/` — no network access required.
