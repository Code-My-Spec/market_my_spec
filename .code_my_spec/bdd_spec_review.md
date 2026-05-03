# BDD Spec Review

## Summary

- **12 stories** reviewed, **104 spec files** audited
- **~38 full-rule violations**, **~25 weak-anchor warnings**, **~30 criterion-scope mismatches**
- **One systemic pattern dominates story 678 + 679 (28 files):** defensive `case live(...) do ... redirect -> "redirect:#{to}" end` followed by `assert html != ""` — passes whether the implementation works or is fundamentally wrong.
- **Skill-content audits (674, 676 static specs)** are the cleanest material; they follow the project's documented pattern for file-backed skills.
- **MCP tool specs (675, 676 dynamic, 612 happy-path)** drive the full HTTP/OAuth/PKCE flow inline rather than the documented "call `Tool.execute/2` with a synthesized `Anubis.Server.Frame`" pattern. This duplicates ~70 lines of OAuth boilerplate per spec and contradicts the project's MCP testing plan in `.code_my_spec/knowledge/bdd/spex/index.md`.
- **`get_flash` regex assertions** crash on nil flash in story 672 and story 609 (Rule 9 violations).
- **Tautological synthetic-bad tests** in 676/5744, 5748, 5750: spec generates a bad string, asserts the bad string is bad.

---

## Per-story findings

### Story 609 — Sign Up And Sign In With Email Magic Link

- **Criteria:** 6 (clean: 2, weak: 1, violations: 3)
- **Story rules ↔ spec coverage:** Magic-link rule covered. "Login renders only magic-link form" rule (5683) is partially covered — spec checks no password form present but **does not** check OAuth buttons render alongside (rule explicitly requires this).

#### Violations

- `criterion_5677_returning_user_signs_in_with_a_fresh_magic_link_spex.exs:37-39` — **Rule 8** (`or` in assert): `assert html =~ "Keep me logged in" or html =~ "Log me in only this time" or html =~ "Log in"`. Replace with `assert has_element?(view, "[data-test='login-submit']")` or a single `=~` regex with `|` alternation.
- `criterion_5684_direct_post_to_password_endpoint_is_rejected_spex.exs:17-22` — **Criterion-scope mismatch.** The criterion (story rule "Direct POST to password endpoint is rejected") asks the spec to POST `user[email] + user[password]` to `/users/log-in` and verify it does not authenticate. The spec POSTs to `/users/update-password` instead — a different endpoint that tests "must be authenticated" rather than the magic-link bypass scenario.
- `criterion_5684_direct_post_to_password_endpoint_is_rejected_spex.exs:33-35` — **Rule 9** (nil-unsafe flash): `assert Phoenix.Flash.get(...) =~ "..."` crashes if flash is nil. Capture the flash, then `assert flash, "..." ; assert flash =~ "..."`.

#### Weak anchors / criterion-scope mismatches

- `criterion_5675_new_visitor_signs_up_via_magic_link_end-to-end_spex.exs:18-34` — **Criterion-scope mismatch.** Story rule asks for "email containing the magic link is delivered (visible at /dev/mailbox in dev)". Spec verifies the redirect HTML mentions an email, but does not actually verify mail was sent. Use `assert_email_sent fn email -> ... end` per project knowledge doc.
- `criterion_5683_login_page_renders_only_the_magic-link_form_spex.exs` — does not assert OAuth buttons (Google, GitHub) are present on `/users/log-in`. Story rule explicitly requires both negative (no password form) AND positive (OAuth buttons present) conditions.

---

### Story 611 — View MCP Connection Instructions

- **Criteria:** 4 (clean: 1, weak: 2, violations: 1)

#### Violations

- `criterion_5697_anonymous_visitor_is_bounced_through_sign-in_to_mcp-setup_spex.exs:39-50` — **Step semantics.** Two `when_` blocks back-to-back (unauth GET to `/mcp-setup`, then magic-link login). Refactor as `given_ "an unauthenticated visitor and a registered user"` setup + single `when_` action. Not a hard rule but per `writing_a_spex.md` `when_` is "the one user action under test."

#### Weak anchors / criterion-scope mismatches

- `criterion_5695_signed-in_user_lands_on_mcp-setup_with_everything_they_need_spex.exs:77-80` — **Weak anchor.** OAuth-instructions check is `has_element?(view, "[data-test='oauth-instructions']")` only. No content check. The criterion requires a "numbered list explaining the OAuth flow" — empty `<div data-test='oauth-instructions'>` would pass.
- `criterion_5698_anonymous_request_gets_no_connection_details_in_the_response_body_spex.exs:25-31` — **Weak anchor.** `assert redirected_to(...)` paired with `refute body =~ "/mcp"` — different subjects. Replace with `assert byte_size(body) < 200` (a redirect body is small) + the refute — same subject (body content).

---

### Story 612 — OAuth Authentication For MCP Connection

- **Criteria:** 8 (clean: 4, weak: 2, violations: 2)
- **Story rules ↔ spec coverage:** Six rules. Most covered. Discovery / metadata covered well. `5694` synthesizes an expired JWT inline rather than driving the OAuth flow + token aging — bypasses the bearer-validation pipeline that the rule is about.

#### Violations

- `criterion_5694_expired_bearer_token_returns_401_with_re-auth_pointer_spex.exs:34-36` — **Rule 8** (`or` inside assert predicate): `Enum.any?(www_auth, fn v -> v =~ "Bearer" and (v =~ "error=" or v =~ "resource_metadata") end)`. Refactor as two separate `assert Enum.any?(www_auth, fn v -> v =~ "Bearer" end)` and use a regex alternation `=~ ~r/error=|resource_metadata/`.
- `criterion_5694_expired_bearer_token_returns_401_with_re-auth_pointer_spex.exs:12` — **Anti-pattern (synthetic bearer).** Hardcoded JWT string `"eyJhbGciOiJub25lIn0..."` short-circuits the OAuth-issuance + expiry path. Either drive the full flow and use a fixture for token aging, or delete the spec — the criterion is about the validation pipeline reacting to an expired-token state, not "any malformed string returns 401."

#### Weak anchors / criterion-scope mismatches

- `criterion_5691_mcp_client_auto-discovers_endpoints_via_well-known_metadata_spex.exs:26-39` — **Criterion-scope mismatch.** Story rule (RFC 8414) requires 6 fields including `code_challenge_methods_supported=["S256"]`, `grant_types_supported`, `response_types_supported`. Spec only checks `authorization_endpoint`, `token_endpoint`, `registration_endpoint`. (5692 covers more; merge or expand.)
- `criterion_5693_mcp_request_with_valid_bearer_is_authenticated_spex.exs:97-100` — **Weak.** `assert context.mcp_conn.status in [200, 201, 202, 400]` accepts 400 in the success set. 400 is not "authenticated successfully." Tighten to `[200, 202]`.
- `criterion_5703_mcp_client_discovers_auth_server_from_mcp_endpoint_url_spex.exs:32` — Criterion requires the WWW-Authenticate header to point at `resource_metadata=...`; spec only checks for the literal "Bearer" token. Add `assert Enum.any?(www_auth, fn v -> v =~ "resource_metadata" end)`.

---

### Story 633 — Public Landing Page

- **Criteria:** 10 (clean: 6, weak: 4, violations: 0)
- **Story rules ↔ spec coverage:** Solid. Each rule has a positive scenario and a quality-gate scenario.

#### Weak anchors / criterion-scope mismatches

- `criterion_5665_visitor_sees_a_real_strategy_artifact_in_the_hero_spex.exs:37-40` — Does not exercise the "above the fold / 1440x900 desktop / 390x844 mobile" viewport constraint from the rule's quality bar. Acceptable scope reduction — but worth a comment in the moduledoc.
- `criterion_5667_visitor_copies_install_command_without_an_auth_gate_spex.exs:36-39` — Anchor `has_element?(install-command)` paired with `refute has_element?(auth-gate)` are different subjects. Tighten by checking the install-command's render still appears in the post-click HTML.
- `criterion_5668_sign-up_gate_in_front_of_install_command_is_rejected_spex.exs:24-39` — Same weak-anchor pattern across three `then_`s.
- `criterion_5673_agency_visitor_finds_the_talk-to-john_lane_below_install_spex.exs` and `criterion_5674_equal-weight_agency_cta_next_to_install_is_rejected_spex.exs` — neither asserts visual ordering / weight per rule "kept visually subordinate." (Rendering-order is observable from the HTML — extract both elements and assert install appears earlier in the document.)

---

### Story 634 — MCP Setup Guide

- **Criteria:** 4 (clean: 3, weak: 0, violations: 0, mismatches: 1)

#### Weak anchors / criterion-scope mismatches

- `criterion_5708_page_missing_one_of_the_three_required_troubleshooting_blocks_is_rejected_spex.exs:42-44` — Rule names the three failure modes as "port conflict, OAuth callback redirect mismatch, Claude Code missing/wrong claude_code version." Spec uses `data-test='mcp-connection-troubleshooting'` — name drift from rule's "Claude Code missing/wrong claude_code version." Align the data-test name or the rule.

---

### Story 672 — Sign Up And Sign In With Google

- **Criteria:** 4 (clean: 1, weak: 1, violations: 3)

#### Violations

- `criterion_5680_user_denies_google_consent_and_recovers_cleanly_spex.exs:35` — **Rule 9** (nil-unsafe flash). `assert get_flash(callback_conn, :error) =~ ~r/.../`. Sister spec `criterion_5686` (GitHub) does the safe pattern (`error_flash = get_flash(...); assert error_flash, "..."; assert error_flash =~ ...`). Mirror that here.
- `criterion_5681_user_changes_google_email_and_still_resolves_to_the_same_mms_account_spex.exs:65` — **Rule 9.** `refute get_flash(...) =~ ~r/.../` crashes on nil. Same fix.
- `criterion_5681_user_changes_google_email_and_still_resolves_to_the_same_mms_account_spex.exs:70` and `criterion_5682_callback_missing_sub_claim_is_rejected_spex.exs:62, 67-68` — same Rule 9 pattern.

#### Weak anchors / criterion-scope mismatches

- `criterion_5681` — Story rule says "match on (provider, provider_user_id) — not email" and "the existing user is reused; no duplicate user is created." Neither check is observable through the spec — they're DB-state claims. Acceptable per boundary rules, but not asserting *any* observable about the integration row's identity beyond the success flash is weak.

---

### Story 673 — Sign Up And Sign In With GitHub

- **Criteria:** 4 (clean: 2, weak: 1, violations: 1)

#### Violations

- `criterion_5687_user_with_private_github_email_still_resolves_consistently_spex.exs:71` — **Rule 9** (`assert get_flash(...) =~ ~r/.../` crashes on nil).

#### Weak anchors / criterion-scope mismatches

- `criterion_5687:65-66` — Anchor `assert redirected_to(...) =~ "/integrations"` paired with `refute get_flash(callback_conn, :error)`. Different subjects (redirect vs flash). The bare `refute get_flash(...)` works (returns nil/false-y) but doesn't co-locate with the positive claim.

---

### Story 674 — Start A Marketing Strategy Interview

- **Criteria:** 12 (clean: 9, weak: 3, violations: 0)
- **Story rules ↔ spec coverage:** All 12 specs are static-content audits over `priv/skills/marketing-strategy/` — consistent with the project pattern documented in `.code_my_spec/knowledge/bdd/spex/index.md`. Static audits are appropriate because runtime agent behavior is not testable server-side. **However:** every criterion's *gherkin scenario* describes runtime agent behavior (transcripts, interview cadence, persona research dispatch). The static specs assert the SKILL.md *tells* the agent to do these things — not that the agent does. Mark this in each moduledoc to avoid drift.

#### Weak anchors / criterion-scope mismatches

- All 12 specs lack a `when_` step. Pattern is `given_ "the SKILL.md", ctx do; ctx |> File.read! ...; {:ok, ctx} end` followed by `then_` assertions. Per `writing_a_spex.md` step semantics, file-loading is `given_` setup, but there is no user *action* — these are static audits. Acceptable for this category, but they should not pretend to be scenario specs. Consider a project-local convention like "audit" instead of "spex/scenario" for these.
- `criterion_5739_step_3_dispatches_research_subagents:28-31` — Two redundant `assert =~ "parallel"` then `assert =~ "in parallel"`. The second subsumes the first.

---

### Story 675 — Skill Behavior Exposed Over MCP (SSE)

- **Criteria:** 10 (clean: 1, weak: 2, violations: 7)
- **Story rules ↔ spec coverage:** All five rules nominally covered. **Major cross-cutting issue:** every dynamic spec drives the full HTTP+OAuth+PKCE flow inline, contradicting the project's documented MCP-tool pattern.

#### Violations

- `criterion_5715, 5716, 5723, 5724, 5725, 5726, 5729` (seven specs) — **Cross-cutting cost violation.** `.code_my_spec/knowledge/bdd/spex/index.md` lines 45-100 documents the canonical pattern: drive MCP tools by calling `Tool.execute/2` directly with a synthesized `Anubis.Server.Frame`. Quote: *"This is the pattern CodeMySpec uses for all of its MCP-tool specs."* These specs instead post raw JSON-RPC over HTTP, requiring a 7-step OAuth setup repeated identically across each file (~70 lines per spec, ~500 lines total of duplicated boilerplate). Two specs *should* drive the HTTP path (one for bearer rejection, one for SSE-vs-non-SSE behavior — that's `5715` and `5716`); the other five (`5723`, `5724`, `5725`, `5726`, `5729`) should be rewritten to call `MarketMySpec.McpServers.Marketing.Tools.{InvokeSkill,ReadSkillFile}.execute/2` directly.
- `criterion_5716_plain_non-sse_client_cannot_read_resource_bodies_spex.exs:104` — **Possible bug.** Spec asserts `body = json_response(context.mcp_conn, 200)`, but the criterion's *own* description says "MMS responds with HTTP 202 Accepted (per Anubis Streamable HTTP behavior)" — not 200. Either the criterion description is wrong or the assertion is.
- `criterion_5730_implementation_that_allows_arbitrary_reads_is_rejected_by_audit_spex.exs:17-35` — **Major: tests source code, not behavior.** Spec reads `lib/market_my_spec/skills/marketing_strategy.ex` and greps for `"Path.safe_relative"`, `"ensure_inside_root"`, `":unsafe_path"`. This couples the spec to the *implementation strings*, not the user-visible contract. The path-traversal scenario is covered behaviorally by `5729`. Delete `5730` or replace it with a behavioral audit (e.g., a property test that fuzzes `read_skill_file` paths).
- `criterion_5727_marketing-strategy_skill_mirrors_the_canonical_plugin_file_tree_spex.exs` — Static layout audit. **Step semantics:** no `when_`. Acceptable for layout audit per project pattern.

#### Weak anchors / criterion-scope mismatches

- `criterion_5723:103-115` — Anchor proven (`name: marketing-strategy`); strong.
- `criterion_5725:119-125` — Anchor `assert content_text =~ ~r/persona|research/i` paired with `refute content_text =~ "steps/01_current_state.md"`. Same subject (content_text). Good.

---

### Story 676 — Strategy Artifacts Saved To My Project

- **Criteria:** 10 (clean: 5, weak: 2, violations: 3)
- **Story rules ↔ spec coverage:** Static audits (5743, 5745, 5746, 5749, 5794) are good. Dynamic audits (5747, 5793) repeat the OAuth boilerplate problem from 675. Synthetic specs (5744, 5748, 5750) are tautological.

#### Violations

- `criterion_5744_step_file_lacking_write_instruction_is_rejected_by_the_audit_spex.exs:11-32` — **Major: tautology.** Spec generates a synthetic `bad_content` string with "no canonical artifact path", then asserts the synthetic string contains no canonical artifact path. The audit *being demonstrated* is never invoked on the real step files. Either run the audit logic from `5743` against the synthetic content (proving it would catch drift), or delete this spec.
- `criterion_5748_a_new_tool_with_content_parameter_fails_the_surface_audit_spex.exs:11-56` — **Major: tautology.** Spec creates a fake tool spec with `properties: %{"content" => ...}`, then asserts the tool spec has a `"content"` property. Same anti-pattern as `5744`.
- `criterion_5750_prompt_edit_introducing_well_save_is_caught_by_the_sweep_spex.exs:20-56` — **Major: tautology.** Spec creates synthetic content with "we'll save", then asserts the synthetic content contains "we'll save". The sweep logic from `5749` is never invoked on the synthetic.
- `criterion_5747_tool_surface_contains_only_the_skill_auth_tools_no_content_sinks_spex.exs` and `criterion_5793_user_completes_step_5_and_finds_positioningmd_in_their_project_spex.exs` — Same OAuth-boilerplate cross-cutting issue as 675. `5747` should call `MarketingServer.tools/0` (or `tools/list` over Frame) directly. `5793` should call `ReadSkillFile.execute(%{path: "steps/05_positioning.md"}, frame)`.

#### Weak anchors / criterion-scope mismatches

- `criterion_5793` — Criterion title is "User completes step 5 and finds positioning.md in their project." That's a client-side write, untestable server-side per the project plan. Spec correctly downgrades to "the skill content tells the agent to write." Add a moduledoc note that the criterion as written is not server-observable so the spec audits the upstream instruction instead.

---

### Story 678 — Multi-Tenant Accounts

- **Criteria:** 15 (clean: 1, weak: 11, violations: 3)
- **Story rules ↔ spec coverage:** Multiple rules have specs that don't actually exercise the rule. **Most specs swallow failure with a defensive case → vacuous string-non-empty assertion.** This is the dominant pattern in this story.

#### Violations

- **Cross-cutting "vacuous defensive case" pattern** in `5766, 5767, 5768, 5771, 5772, 5774, 5776, 5777, 5778, 5779, 5780` (eleven of fifteen specs):

  ```elixir
  picker_html =
    case live(context.conn, "/accounts/picker") do
      {:ok, _v, html} -> html
      {:error, {:redirect, %{to: to}}} -> "redirect:#{to}"
      {:error, {:live_redirect, %{to: to}}} -> "redirect:#{to}"
      _ -> ""
    end
  # ...
  then_ "the picker rendered" do
    assert is_binary(picker_html)
    assert picker_html != ""
    :ok
  end
  ```

  This is exactly the anti-pattern the original prompt called out: *"any case where the then_ would pass even if the implementation is fundamentally wrong (e.g., dashboard_html != "" with dashboard_html set to 'redirect:/some/path')."* Both branches of the case produce a non-empty binary; the `assert html != ""` is permanently true. The spec proves nothing about which branch fired.

  **Fix pattern:** decide which outcome the criterion requires and assert it directly. If the criterion is "user sees the picker", `assert {:ok, view, _html} = live(conn, "/accounts/picker")`. If the criterion is "user is redirected", `assert {:error, {:live_redirect, %{to: "/accounts/new"}}} = live(...)`. Don't accept both.

- `criterion_5769_invited_user_receives_exactly_one_role_in_the_account_spex.exs:74-77` — **Major vacuous assertion.** `owner_count = ... |> Kernel.-(1); assert owner_count >= 0`. `String.split` returns at least one element, so `length - 1 >= 0` is always true. The criterion (single `account_members` record) needs `assert owner_count == 1`.
- `criterion_5770_adding_an_existing_member_a_second_time_is_rejected_spex.exs:42-50` — **Criterion-scope mismatch.** The criterion is "second add is rejected" but the `when_` step doesn't actually invite the member twice. It just renders `/accounts`. The spec's `refute accounts_html =~ ~r/added twice|duplicate member/i` proves nothing — that text wouldn't appear in any normal accounts list anyway.

#### Weak anchors / criterion-scope mismatches

- `criterion_5774_duplicate_slug_is_rejected_at_creation_spex.exs:69` — Refute pattern is `~r/^redirect:\/accounts\/[a-z0-9-]+$/` matching the synthetic `"redirect:..."` string from the case. After `render_submit`, the form result is binary HTML on validation failure or `{:error, {:redirect, ...}}` on success. The refute would only ever fire if the case branch produced the redirect-prefix sentinel — which only happens on success. So the spec passes vacuously when the form re-renders with an error AND when it redirects. Replace with `assert form_html =~ "must be unique"` (or whatever error is shown).
- `criterion_5777_self-service_account_creation_always_produces_an_individual_account_spex.exs:79` — Refute regex `~r/Agency Sneak Attempt[^<]*\bagency\b/i` is fragile (depends on inline HTML structure between two strings). Stronger: assert the rendered account name has `data-test='account-type-individual'` or similar.
- `criterion_5778_admin-provisioned_agency_account_unlocks_agency_features_spex.exs` — The criterion is about admin provisioning unlocking features. The spec sign-in is a normal user, no admin-provisioned account exists, and the spec just visits `/accounts` and refutes "forbidden|access denied". Doesn't exercise the criterion at all.

---

### Story 679 — Agency Account Type And Client Dashboard

- **Criteria:** 13 (clean: 0, weak: 11, violations: 2)
- **Story rules ↔ spec coverage:** Same dominant defensive-case pattern as 678. **Worse:** several criteria are about a specific user action (revoke originator access, grant invited access, attempt duplicate grant) that the spec never drives — the `when_` step just visits a page.

#### Violations

- **Cross-cutting "vacuous defensive case" pattern** in all 13 specs (5781, 5782, 5783, 5784, 5785, 5786, 5788, 5789, 5790, 5791, 5792, 5795, 5796). Same shape as 678. Every dashboard spec resolves to `dashboard_html != ""` + `refute html =~ ~r/forbidden|access denied/i`. The forbidden/access-denied refute is the only substantive check — and it's a poor proxy for any of these criteria.
- `criterion_5784_originator_access_grant_cannot_be_revoked_spex.exs:48-54` — **Major: error-swallowing rescue.** `try / rescue _ -> "no-revoke-control"` swallows ALL exceptions as a benign string. If the LiveView crashes for unrelated reasons, the spec passes. Use `if has_element?(view, "[data-test='revoke-originator']") do ... end` to branch on element existence without catching errors.
- `criterion_5786_either_party_can_revoke_an_invited_access_grant_spex.exs` — Criterion is "either party CAN revoke." Spec doesn't drive a revoke from either side. Just visits `/agency` and `/accounts` and refutes "access denied." **Criterion not exercised.**
- `criterion_5790_attempting_to_grant_access_for_an_already-granted_agency-client_pair_is_rejected_spex.exs` — Criterion is "duplicate grant rejected." Spec doesn't grant access once, let alone twice. Just visits `/accounts`.

#### Weak anchors / criterion-scope mismatches

- `criterion_5783` — Criterion: "agency creates client → agency becomes originator." Spec creates a client form-submit but never asserts originator status. Just refutes "access denied."
- `criterion_5785` — Criterion: "client account grants agency invited access" → spec doesn't drive the grant.
- `criterion_5788` — Criterion: "agency owner clicks into a client and lands inside that client account context." Spec doesn't click into a client; just refutes access denied on `/agency`.
- `criterion_5789` — Criterion: "read-only agency user cannot edit settings." Spec doesn't establish a read-only access grant. Just visits `/agency`.
- `criterion_5791, 5795, 5796` (column / row content audits) — These work *if* the dashboard route renders. They use the same vacuous case but the refutes are at least targeted (`<th>status</th>`, `data-test='status-column'`, billing keywords). Marginal.

---

## Cross-cutting patterns

1. **Defensive case + non-empty-string assertion (28 specs across 678/679).** Largest single source of weakness. Every case where the implementation could send the user anywhere — render, redirect, error, crash, missing route — is collapsed into a string and the test passes. Re-write to commit to the criterion's expected outcome and assert that outcome directly.

2. **OAuth boilerplate in MCP-tool specs (12+ specs across 612, 675, 676).** ~70 lines of inline OAuth/PKCE setup repeated in spec after spec. Project knowledge `.code_my_spec/knowledge/bdd/spex/index.md` documents the *direct tool execution* pattern with `Anubis.Server.Frame`. Adopting it would: cut these specs to ~15 lines each, isolate the OAuth flow to two specs (`5715`+`5716` and `5732`), and make tool-behavior specs actually test tool behavior.

3. **`get_flash` regex on a possibly-nil flash (4 specs across 609, 672, 673).** `get_flash(conn, :key) =~ regex` crashes if no flash is set. Story 673's `5686` shows the right pattern (`flash = get_flash(...); assert flash, "..."; assert flash =~ ...`) — apply uniformly.

4. **Tautological synthetic-bad tests (3 specs in 676).** "Generate a string with property X, assert it has property X." These add no signal. Either run the audit logic from the positive spec against the synthetic string, or delete the spec.

5. **Static-content audits without `when_` (12 specs in 674, 5 in 676, 1 in 675).** No user action — just `given_ :file_contents` + `then_ :assertions`. This is the right pattern for the file-backed skill, but it doesn't fit the `spex/scenario` shape. Consider a project-local convention (e.g., `audit "..."` macro) so these don't claim to be scenarios when they're file checks.

6. **Tests grepping implementation source (1 spec, `5730`).** Asserting that `lib/.../marketing_strategy.ex` source contains the literal string `Path.safe_relative` couples the spec to implementation rather than contract. Behavioral coverage of the same property already exists in `5729`.

---

## Priority fix list

1. **Rewrite all 28 specs in 678/679** to drop the `case ... -> "redirect:#{to}"` defensive pattern. Each spec should commit to the criterion's expected branch and pattern-match it.
2. **Delete or replace `criterion_5784:48-54` (679) `try/rescue`** — never swallow errors as success.
3. **Rewrite `criterion_5786, 5788, 5789, 5790` (679) and `criterion_5770, 5778` (678)** to actually drive the user action the criterion describes (revoke, click-through, attempt duplicate, admin-provision).
4. **Migrate `5723, 5724, 5725, 5726, 5729` (675) and `5747, 5793` (676)** to call MCP tool modules directly via `Anubis.Server.Frame` per project plan. Keep `5715`, `5716`, `5732` as HTTP-flow specs.
5. **Delete `5730` (675).** Behavior covered by `5729`; source-grep adds no signal.
6. **Rewrite `5744`, `5748`, `5750` (676)** to invoke the audit logic on the synthetic content, or delete them if `5743`, `5747`, `5749` adequately cover the positive case.
7. **Fix Rule 9 nil-flash crashes** in `5680`, `5681`, `5682` (672), `5687` (673), `5684` (609). One-line guard pattern from `5686`.
8. **Fix Rule 8 `or` in assert** in `5677` (609) and `5694` (612).
9. **Fix `5684` (609) endpoint mismatch:** the spec POSTs to `/users/update-password`; the criterion asks about POSTing password to `/users/log-in`.
10. **Fix `5769:74-77` (678)** vacuous `owner_count >= 0` to `owner_count == 1`.
