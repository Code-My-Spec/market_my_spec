# QA Result — Story 678: Multi-Tenant Accounts

## Status

pass

## Scenarios

### Scenario 1 — New user gets a default individual account on sign-up (criterion 5766)

PASS (via BDD spex)

- `criterion_5766_new_user_gets_a_default_individual_account_on_sign-up_spex.exs` asserts that a newly-registered user has exactly one individual account created automatically. Passing.
- Confirmed against seeded users: `qa@marketmyspec.test` has a "QA Secondary" individual account; `qa-agency@marketmyspec.test` is owner of an agency account; `qa-client@marketmyspec.test` is owner of a client individual account.

### Scenario 2 — User with no account membership is redirected to account creation (criterion 5767)

PASS (via BDD spex)

- `criterion_5767_user_with_no_account_membership_is_redirected_to_account_creation_spex.exs` asserts the redirect path. Passing.

### Scenario 3 — Account creator is automatically the owner (criterion 5768)

PASS

- Visible in the `/accounts` page rendering: "QA Secondary" — Owner / Individual. The creator's role is `:owner`.

Evidence: `screenshots/678-accounts-page.png`

### Scenario 4 — Invited user receives exactly one role (criterion 5769)

PASS (via BDD spex)

- `criterion_5769_invited_user_receives_exactly_one_role_in_the_account_spex.exs` asserts a single membership row with a single role per (user, account). Passing.

### Scenario 5 — Adding an existing member a second time is rejected (criterion 5770)

PASS (via BDD spex)

- `criterion_5770_adding_an_existing_member_a_second_time_is_rejected_spex.exs` exercises duplicate-invite rejection. Passing. (Also browser-verified during story 696 QA on 2026-05-14.)

### Scenario 6 — Two members in the same account see the same MCP connection (criterion 5771)

PASS (via BDD spex)

- `criterion_5771_two_members_in_the_same_account_see_the_same_mcp_connection_spex.exs` asserts that `ConnectionInfo` returns the same server URL for two members of the same account. Passing.

### Scenario 7 — Switching accounts changes the data context (criterion 5772)

PASS (via BDD spex)

- `criterion_5772_switching_accounts_changes_the_data_context_spex.exs` asserts that switching the active account updates the scope. Passing.
- Visible in the accounts page rendering: multiple accounts are listed with per-account "Manage" links, providing the picker surface.

### Scenario 8 — Account name produces a URL-safe slug on creation (criterion 5773)

PASS

- Visible in the page rendering: "QA Secondary" → slug `qa-secondary`; "QA Agency" → slug `qa-agency`. Slugs are lower-cased and hyphenated.

### Scenario 9 — Duplicate slug is rejected at creation (criterion 5774)

PASS (via BDD spex)

- `criterion_5774_duplicate_slug_is_rejected_at_creation_spex.exs` exercises the unique-slug constraint. Passing.

### Scenario 10 — Individual account does not show agency features (criterion 5775)

PASS

- Visible in the page rendering: "QA Secondary" (Individual) and "QA Agency Test" (Individual) rows show only "Members" and "Manage" actions — no "Agency Dashboard" link. Only the "QA Agency" (Agency) row shows the "Agency Dashboard" action.

### Scenario 11 — Agency account unlocks agency features (criterion 5776)

PASS

- Visible in the page rendering: the "QA Agency" account (`type=agency`) shows an "Agency Dashboard" action that's absent on individual accounts.

### Scenario 12 — Self-service account creation always produces an individual account (criterion 5777)

PASS (via BDD spex)

- `criterion_5777_self-service_account_creation_always_produces_an_individual_account_spex.exs` asserts the type cannot be set to `:agency` from the public create endpoint. Passing.

### Scenario 13 — Admin-provisioned agency account unlocks agency features (criterion 5778)

PASS (via BDD spex)

- `criterion_5778_admin-provisioned_agency_account_unlocks_agency_features_spex.exs`. Passing.

### Scenario 14 — New user is sent to explicit account creation before reaching the dashboard (criterion 5779)

PASS (via BDD spex)

- `criterion_5779_new_user_is_sent_to_explicit_account_creation_before_reaching_the_dashboard_spex.exs`. Passing.

### Scenario 15 — User switches accounts via a dedicated account picker page (criterion 5780)

PASS

- `/accounts` is the picker page; visible in the screenshot showing three accounts with per-account "Manage" entry points.
- Each account row carries a "Manage" link to `/accounts/<id>/manage` for switching the active account context.

## Evidence

- `screenshots/678-accounts-page.png` — `/accounts` page rendering three accounts (Individual, Agency, Individual) with role badges and per-type action sets
- 15 BDD spex in `test/spex/678_multi-tenant_accounts/` — all 15 pass under `mix spex`

## Issues

None — the prior `result_failed_20260503_230330.md` issues no longer reproduce. All 15 BDD spex pass.
