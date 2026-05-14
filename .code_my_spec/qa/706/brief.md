# Qa Story Brief

Story 706 — Pull full thread content into a unified format for the LLM

## Tool

- MCP browser tools (Vibium) for the ThreadLive.Index and ThreadLive.Show UI pages
- `mix spex` for the Elixir-level BDD tests covering MCP tool, source adapters, schema, and caching

## Auth

Sign in via the magic-link URL printed by the seed script:

```
mix run priv/repo/qa_seeds.exs
# Copy the magic-link URL for qa@marketmyspec.test and navigate to it in the browser
```

The dev server must be running: `PORT=4008 mix phx.server`

## Seeds

Run the base QA seeds to create the authenticated user and account:

```
mix run priv/repo/qa_seeds.exs
```

No story-specific seed script is required. The thread list page is tested with an empty threads table (the scaffold shows an empty-state message when no threads exist).

To manually seed a thread record for the Show page test, use `iex -S mix phx.server` and insert via `MarketMySpec.Repo.insert!`.

## What To Test

### Spex suite (automated)

Run all BDD spex and confirm all pass:

```
MIX_ENV=test mix spex
```

Expected: all 249 tests pass (includes Story 706 criteria).

Story 706 criteria covered by spex:
- Criterion 6125 — LLM calls get_thread and receives full thread (MCP tool)
- Criterion 6126 — Reddit and ElixirForum adapters return normalized Thread shape
- Criterion 6127 — Comment hierarchy field present in both adapter responses
- Criterion 6128 — Response contains title, op_body/body, and comments/comment_tree fields
- Criterion 6129 — Thread changeset valid with raw_payload and empty comment_tree
- Criterion 6130 — Consecutive get_thread calls return identical content (cache semantics)
- Criterion 6174 — Agent fetches Reddit thread by ID via get_thread MCP tool
- Criterion 6175 — Reddit and ElixirForum responses share same top-level shape (source, thread_id keys)
- Criterion 6176 — Repeat fetch returns identical content within freshness window
- Criterion 6177 — Response is valid JSON with a comments field (list or nil) containing at most 25 entries
- Criterion 6178 — Unknown source returns tuple (not crash); valid source succeeds after error attempt
- Criterion 6179 — Thread changeset valid with raw_payload and nil op_body

### UI: ThreadLive.Index — empty state

1. Sign in via the magic-link URL (navigate Vibium to the URL)
2. Navigate to `/accounts/:id/threads` using the QA account ID
3. Verify the page renders with heading "Threads"
4. Verify the `data-test="threads-empty"` row appears with "No threads have been ingested yet."
5. Screenshot the threads list page (empty state)

### UI: ThreadLive.Show — scaffold view

1. Navigate directly to `/accounts/:account_id/threads/some-fake-thread-id`
2. Verify the page renders without error
3. Verify `data-test="thread-id"` shows "Thread ID: some-fake-thread-id"
4. Verify `data-test="no-touchpoints"` shows "No staged drafts yet."
5. Screenshot the thread show page

### Source adapter behavior (exploratory)

Confirm via the spex results that:
- `Reddit.get_thread/2` returns a map with keys `[:id, :source, :title, :op_body, :comments]`
- `ElixirForum.get_thread/2` returns the same shape
- Both adapters return stub data at scaffold stage (real API integration is pending)

## Result Path

`.code_my_spec/qa/706/result.md`
