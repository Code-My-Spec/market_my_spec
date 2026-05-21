# QA Brief — Story 738: Polish Touchpoint prose with model help and Vale lint feedback

## Tool

`mix run -e '...'` — single BEAM boot, in-process MCP tool execution via synthesized Anubis.Server.Frame.

No HTTP transport (no POST /mcp route). The tool is driven via `PolishTouchpoint.execute(args, frame)` exactly as the BDD spex do.

## Auth

No browser auth required. Scopes are created programmatically using `MarketMySpec.UsersFixtures.account_scoped_user_fixture/0`, which returns a `%Scope{}` with `active_account_id` set. Frame is synthesized as:

```elixir
frame = %{
  assigns: %{current_scope: scope},
  context: %{session_id: "qa-738-<n>"}
}
```

For scenarios that require a saved Vale config (6512, 6516, 6517, 6519), `MarketMySpec.Linter.save_config(scope, vale_ini)` is called directly in-process (bypassing LiveView form, which the spex use but is not required for direct tool testing).

## Seeds

No `qa_seeds.exs` needed — all state is created in-process within the single `mix run -e` invocation:
- Two account-scoped users (Sam, Bea) via `account_scoped_user_fixture/0`
- Threads via `MarketMySpec.EngagementsFixtures.thread_fixture/2`
- Touchpoints staged via `StageResponse.execute/2`
- Vale config saved via `MarketMySpec.Linter.save_config/2`

Pre-condition: `write-good` must be installed at `priv/vale/styles/write-good/`. Verified: installed via `vale sync` from a temp `.vale.ini` with `Packages = write-good`.

Environment: `VALE_STYLES_PATH=/Users/johndavenport/Documents/github/market_my_spec/priv/vale/styles` (from `envs/dev.env`).

## What To Test

7 scenarios derived from acceptance criteria in `test/spex/738_*/`:

### Scenario 6510 — polish_touchpoint writes polished_body (no Vale config)
1. Create scope (Sam), build frame
2. Create thread, stage a touchpoint via `StageResponse.execute`
3. Call `PolishTouchpoint.execute(%{touchpoint_id: id, polished_body: clean_prose}, frame)`
4. Call `ListTouchpoints.execute(%{thread_id: thread.id}, frame)`
5. Assert: touchpoint's `polished_body` equals the clean prose passed

### Scenario 6512 — Vale lints against account's saved configuration
1. Create scope (Sam), save `.vale.ini` with `BasedOnStyles = write-good` via `Linter.save_config`
2. Stage a touchpoint
3. Call `PolishTouchpoint.execute` with prose containing "very" (weasel word)
4. Assert: response `alerts` list is non-empty and contains a write-good alert

### Scenario 6513 — No Vale config returns empty alert list
1. Create scope (Sam), do NOT save any Vale config
2. Stage a touchpoint
3. Call `PolishTouchpoint.execute` with weasel-word prose
4. Assert: response `alerts` is `[]`

### Scenario 6515 — Cross-account access returns not_found
1. Create scope A (Sam) with a staged touchpoint
2. Create scope B (Bea) with frame_b
3. Call `PolishTouchpoint.execute` with frame_b but Sam's touchpoint_id
4. Assert: response has `isError: true`
5. Assert: Sam's touchpoint `polished_body` is still nil

### Scenario 6516 — Alert objects are flat maps with required fields
1. Create scope, save write-good config, stage touchpoint
2. Call `PolishTouchpoint.execute` with "This is very interesting and very useful."
3. Assert: each alert has `severity` (string), `check` (string), `line` (integer), `column` (integer), `message` (string)
4. Assert: `alerts` is a flat list, not Vale's raw file-path keyed map

### Scenario 6517 — Clean prose with config saved writes body, no alerts
1. Create scope, save write-good config, stage touchpoint
2. Call `PolishTouchpoint.execute` with clean prose that triggers no write-good rules
3. Assert: response `alerts` is `[]`
4. Assert: touchpoint's `polished_body` is persisted via ListTouchpoints

### Scenario 6519 — Lint alerts block the write; body unchanged
1. Create scope, save write-good config, stage touchpoint (polished_body nil)
2. Call `PolishTouchpoint.execute` with "This is very useful and very interesting overall."
3. Assert: response `alerts` is non-empty
4. Assert: touchpoint's `polished_body` is still nil (not persisted)

## Result Path

`.code_my_spec/qa/738/result.md`
