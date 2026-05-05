# QA Brief — Story 676: Strategy Artifacts Saved To My Account

## Tool

web (Vibium MCP browser tools) for UI scenarios; static file inspection via shell for skill content audits; `mix spex` for automated spex execution.

## Auth

Use the seeded magic-link URL printed by `mix run priv/repo/qa_seeds.exs` (run on port 4008). Navigate Vibium directly to the magic-link URL to sign in without going through email.

Login URL: `http://localhost:4008/users/log-in`
Seeded user: `qa@marketmyspec.test`

Note: the QA seeds script targets port 4007 in its output message, but the current code runs on port 4008. Use 4008 for all browser testing.

## Seeds

```
cd /Users/johndavenport/Documents/github/market_my_spec && mix run priv/repo/qa_seeds.exs
```

The seeded user (`qa@marketmyspec.test`) will not have an account with files since the Files context requires S3 credentials and MCP tool modules (`WriteFile`, `ReadFile`, `ListFiles`) that are not yet implemented. The seed is still needed to get a valid authenticated session for the UI tests.

## What To Test

### Scenario 1: Skill content audit — step files have write_file directives (criteria 5843, 5844)

Verify all 8 step files under `priv/skills/marketing-strategy/steps/` contain:
- A `write_file` MCP tool reference
- Their canonical `marketing/NN_*.md` destination path

Check each step file manually:
- `steps/01_current_state.md` — should reference `write_file` and `marketing/01_current_state.md`
- `steps/02_jobs_and_segments.md` — should reference `write_file` and `marketing/02_jobs_and_segments.md`
- `steps/03_persona_research.md` — should reference `write_file` and `marketing/03_personas.md`
- `steps/04_beachhead.md` — should reference `write_file` and `marketing/04_beachhead.md`
- `steps/05_positioning.md` — should reference `write_file` and `marketing/05_positioning.md`
- `steps/06_messaging.md` — should reference `write_file` and `marketing/06_messaging.md`
- `steps/07_channels.md` — should reference `write_file` and `marketing/07_channels.md`
- `steps/08_plan.md` — should reference `write_file` and `marketing/08_plan.md`

### Scenario 2: Destination filenames match canonical table (criterion 5845)

Verify no step file references a `marketing/NN_*.md` path outside the canonical 8-entry list. No absolute `/marketing/` paths (with leading slash). No `accounts/` prefix in step files.

### Scenario 3: Drifted filenames are rejected (criterion 5846)

Verify no step file contains timestamped (`_YYYYMMDD`, `_YYYY-MM-DD`), versioned (`_vN`, `_copy`, `_final`), or absolute path variants. The canonical relative paths must be the only ones referenced.

### Scenario 4: Skill content sweep — no local-filesystem language (criteria 5847, 5848)

Check `SKILL.md` and all 8 step files for banned phrases:
- "write tool"
- "./marketing/"
- "your local marketing"
- "in your working directory"
- "commit to git locally"
- "on the user's machine"
- "local filesystem"
- "use your Write tool" (case-insensitive)

None of these phrases should appear anywhere in the skill files.

### Scenario 5: UI — /files page loads for authenticated user (criterion 5849 — partial)

Navigate to `http://localhost:4008/files` after authenticating. The page should load and show either "No artifacts yet" (if no S3 files exist for the account) or a list of files. It should NOT 404, 500, or redirect to login.

Capture a screenshot of the /files page.

### Scenario 6: UI — /files scoped to account, not user (criterion 5849 — account scoping audit)

The `FilesLive.Index` calls `Files.list(scope, "")` which calls `resolve(scope, "")` which checks `scope.active_account_id`. If the scope has no active account, `Files.list` returns `{:error, :no_active_account}` and `load_groups/1` returns `[]`. Verify:

- A user without an active account sees the empty state ("No artifacts yet"), not a 500 or server error.
- The Files context prefix is `accounts/{account_id}/` — files are scoped to account, not user.

### Scenario 7: Automated spex run (all criteria)

Run `MIX_ENV=test mix spex` and capture which 676 criteria pass/fail. Expected:
- 5843, 5844, 5845, 5846, 5847, 5848: PASS (static file audits)
- 5849, 5850: FAIL with `UndefinedFunctionError` for `WriteFile`, `ReadFile`, `ListFiles` modules (not yet implemented)

## Result Path

`.code_my_spec/qa/676/result.md`
