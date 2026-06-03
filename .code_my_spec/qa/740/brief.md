# QA Brief: Story 740 — Pluggable Data Sources Behind a Fixed Validation Contract

## Tool

Code inspection + MCP tool dogfooding via direct Elixir module calls. This story has no browser UI surface. Testing uses:
- Source code and module introspection (behaviour, exports)
- Direct function calls on `MarketMySpec.ProblemDiscovery.Source.Upwork` via `mix run -e`
- MCP tool execution via `mcp__plugin_codemyspec_local__*` wrappers or equivalent dogfooding for CreateFrame / GetFrame / RunScore surfaces
- Changeset validation by reading the `JobPosting` schema

## Auth

No browser auth needed. Dev server running at http://localhost:4007 with `APIFY_API_TOKEN` set.

For MCP tool calls that require a bearer token, obtain one from the dev database:

```bash
cd /Users/johndavenport/Documents/github/market_my_spec
mix run -e 'IO.inspect(MarketMySpec.Repo.all(MarketMySpec.MCP.ApiToken))'
```

The QA seeds (if needed) create a user at `qa@marketmyspec.test` / `hello world!`.

## Seeds

No story-specific seeds required. The adapter contract tests are structural and unit-level. Run the base seeds only if exercising MCP tool calls end-to-end:

```bash
cd /Users/johndavenport/Documents/github/market_my_spec
mix run priv/repo/qa_seeds.exs
```

## What To Test

### Scenario 1: Source.Upwork implements the Source behaviour (criterion 6541)

Verify at the code level:
- `lib/market_my_spec/problem_discovery/source/upwork.ex` declares `@behaviour MarketMySpec.ProblemDiscovery.Source`
- The module exports `search/2` which is the only callback defined on the behaviour
- `Source.impl_for("upwork")` returns `{:ok, MarketMySpec.ProblemDiscovery.Source.Upwork}`
- `Source.impl_for("reddit")` (or any unknown source) returns `{:error, :unknown_source}`

### Scenario 2: A second adapter ships with zero diff to Score / Red-team (criterion 6537)

Verify structurally:
- `lib/market_my_spec/problem_discovery/pipeline.ex` (Score stage) contains no hardcoded reference to the Upwork adapter — it dispatches through `Source.search/2`
- `lib/market_my_spec/problem_discovery/board.ex` contains no hardcoded Upwork adapter reference
- `lib/market_my_spec/mcp_servers/problem_discovery/tools/red_team_candidate.ex` contains no hardcoded Upwork reference
- `Source.impl_for/1` is the ONLY place where new adapters would need to be registered

### Scenario 3: UpworkAdapter normalizes posting + client metadata as raw values (criterion 6538)

Inspect `normalize/1` in `upwork.ex`:
- Returns a map with exactly: `source`, `source_id`, `title`, `description`, `url`, `total_spent_cents`, `hire_rate`
- Does NOT include computed fields: `score`, `verdict`, `embedding`, `signal_strength`
- `total_spent_cents` converts raw number to cents (multiplied by 100)
- `hire_rate` converts decimals (0.0-1.0) to integer percentage

### Scenario 4: Adapter reads credentials from Application config, not Integrations (criterion 6542)

Verify in `upwork.ex`:
- `default_api_key/0` reads from `Application.get_env(:market_my_spec, __MODULE__, []) |> Keyword.get(:api_key)`
- `runtime.exs` wires `APIFY_API_TOKEN` env var into `config :market_my_spec, Source.Upwork, api_key:` (not an Integrations OAuth token)
- The file does NOT import or alias `MarketMySpec.Integrations`
- Check `runtime.exs` line ~91: `config :market_my_spec, MarketMySpec.ProblemDiscovery.Source.Upwork, api_key: env!("APIFY_API_TOKEN", :string, nil)`

**Note:** `default_api_key/0` has a secondary fallback to `System.get_env("APIFY_API_TOKEN")` directly after Application config. This is a belt-and-suspenders pattern, but the spex for criterion 6543 only deletes `UPWORK_API_KEY` (not `APIFY_API_TOKEN`). With `APIFY_API_TOKEN` present in the dev environment, the missing-credential test in spex may behave differently than in the test env. Flag this discrepancy.

### Scenario 5: Missing credential returns error tuple (criterion 6543)

Verify the `require_api_key/1` guard:
- `require_api_key(nil)` returns `{:error, :missing_upwork_api_key}`
- `require_api_key("")` returns `{:error, :missing_upwork_api_key}`
- `require_api_key("valid-key")` returns `{:ok, "valid-key"}`
- The spex clears Application config and `UPWORK_API_KEY` but NOT `APIFY_API_TOKEN` — if `APIFY_API_TOKEN` is in the test environment, the "missing credential" test may not return the error tuple. Inspect whether the spex passes for the right reason.

### Scenario 6: Frame artifact contains source-query pairs (criterion 6544)

Via MCP tool dogfooding or code inspection:
- `CreateFrame` accepts `saved_searches: [%{source: "upwork", query: "..."}]`
- `GetFrame` returns those pairs verbatim in `saved_searches`
- The Frame schema stores the pairs without transformation
- Inspect `lib/market_my_spec/problem_discovery/frame.ex` to confirm the field is stored as-is

### Scenario 7: Score emits one PaidJobSignal per JobPosting (criterion 6539)

Via code inspection of `pipeline.ex`:
- The Score stage iterates JobPostings and creates one `PaidJobSignal` per posting
- `PaidJobSignal` has `verdict` and strength fields (check `paid_job_signal.ex`)
- RunScore MCP tool returns `per_candidate` payload with gated_in/gated_out counts

### Scenario 8: PaidJobSignal job_posting association (criterion 6540)

Inspect `paid_job_signal.ex`:
- `belongs_to :job_posting, JobPosting` (not has_many — single record)
- The Board query preloads `:job_posting` (not `:job_postings`)
- Each signal has exactly one `job_posting` struct when preloaded

### Scenario 9: JobPosting with nil required field is rejected (criterion 6545)

Inspect `job_posting.ex` changeset:
- `validate_required/2` includes `:title`, `:source`, `:source_id`, `:description`, `:embedding`, `:frame_id`, `:saved_search_index`, `:gathered_at`
- A changeset built without `:title` should be invalid with an error on `:title`

## Result Path

`.code_my_spec/qa/740/`

## Setup Notes

This is a code-contract story — the acceptance criteria are structural guarantees about how the adapter plugs in, not UI flows. All scenarios can be verified via:
1. Direct source code inspection
2. Running the BDD spex in test mode (all 9 pass per user confirmation)
3. Live function calls where the dev server and APIFY_API_TOKEN are available

The dev server is at port 4007 with `APIFY_API_TOKEN` set. The credential concern in criterion 6542/6543 is worth close inspection: the `default_api_key/0` fallback chain includes `System.get_env("APIFY_API_TOKEN")` directly, which means if the env var is present, clearing Application config alone won't trigger the missing-credential error.
