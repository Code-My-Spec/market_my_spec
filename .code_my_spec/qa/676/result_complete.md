# QA Result — Story 676: Strategy Artifacts Saved To My Account

## Status

pass

## Scenarios

This story's contract is about the persistence boundary between the LLM agent's per-step write_file directives and the account-scoped file API exposed over MCP. It is enforced almost entirely by skill-content audits (the step prompts must say "write via write_file" and never "save to your local filesystem") plus the MCP tool surface audit (only the skill + auth tools + file CRUD, no content sinks).

### Scenario 1 — Each step file passes the write_file directive audit (criterion 5843)

PASS (via BDD spex)

- `criterion_5843_each_step_file_passes_the_write_file_directive_audit_spex.exs` scans every step prompt file and asserts each one carries an explicit "write via write_file" directive. Passing.

### Scenario 2 — Step file lacking write_file directive is rejected (criterion 5844)

PASS (via BDD spex)

- `criterion_5844_step_file_lacking_write_file_directive_is_rejected_spex.exs` exercises the audit against a synthesized step file with no directive and asserts rejection. Passing.

### Scenario 3 — Destination filenames match the canonical table (criterion 5845)

PASS (via BDD spex)

- `criterion_5845_destination_filenames_match_the_canonical_table_spex.exs` audits each step prompt's instructed filename against the canonical table (current-state.md, jobs-segments.md, personas.md, beachhead.md, positioning.md, messaging.md, channels.md, 90-day-plan.md or equivalents). Passing.

### Scenario 4 — Drifted filename is rejected (criterion 5846)

PASS (via BDD spex)

- `criterion_5846_drifted_filename_eg_timestamped_variant_is_rejected_spex.exs` exercises the audit against a step that names a timestamped variant and asserts rejection. Passing.

### Scenario 5 — Skill content sweep finds no local-filesystem language (criterion 5847)

PASS (via BDD spex)

- `criterion_5847_skill_content_sweep_finds_no_local_filesystem_language_spex.exs` greps the entire skill content for terms that imply local filesystem persistence ("your local machine", "your local files", "save to disk", etc.) and asserts zero hits. Passing.

### Scenario 6 — Prompt edit introducing local-filesystem language is caught (criterion 5848)

PASS (via BDD spex)

- `criterion_5848_prompt_edit_introducing_local_filesystem_language_is_caught_spex.exs` simulates an editorial regression by injecting local-filesystem language and asserts the sweep flags it. Passing.

### Scenario 7 — User completes step 5 and finds positioning in account workspace (criterion 5849)

PASS (via BDD spex)

- `criterion_5849_user_completes_step_5_and_finds_positioning_in_account_workspace_spex.exs` exercises the full step-5 flow through the MCP file API and asserts a `positioning.md` artifact exists in the account workspace. Passing.

### Scenario 8 — Re-running overwrites stable filenames (criterion 5850)

PASS (via BDD spex)

- `criterion_5850_re_running_overwrites_stable_filenames_spex.exs` runs the step-5 write twice and asserts only one file exists (no numbered or timestamped duplicate). Passing.

## Evidence

- `screenshots/676-mcp-setup.png` — `/mcp-setup` install page that documents how the MCP file tools are wired
- 8 BDD spex in `test/spex/676_strategy_artifacts_saved_to_my_account/` — all 8 pass under `mix spex`

## Issues

None — the prior `result_failed_20260504_033737.md` issues no longer reproduce. All 8 BDD spex pass.
