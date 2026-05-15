# QA Result — Story 679: Agency Account Type And Client Dashboard

## Status

pass

## Environment

- Server: `PORT=4008 mix phx.server`
- Date: 2026-05-14
- Seeds: `mix run priv/repo/qa_seeds.exs`
- QA users: `qa@marketmyspec.test` (individual), `qa-agency@marketmyspec.test` (agency), `qa-client@marketmyspec.test` (individual/client)

## Scenarios

### Scenario 1: Route existence check — /agency vs /agency/dashboard

PASS (with note)

- `/agency` — renders the Client Dashboard for authenticated agency users. Route exists and is correct.
- `/agency/dashboard` — returns 404 `Phoenix.Router.NoRouteError`. This route does NOT exist.
- The brief noted `/agency/dashboard` as the expected route — it is not. The router mounts the agency dashboard at `/agency`, which is what all 13 BDD spex also navigate to. The route is correct and consistent with the BDD specs.
- `/agency` is in `live_session :require_agency_account` with three on_mount guards: `require_authenticated`, `require_account_membership`, and `require_agency_account`.

Evidence: s01-agency-dashboard-agency-user.png, s06-agency-dashboard-404.png

### Scenario 2: Agency dashboard renders for agency-typed account

PASS

- Signed in as `qa-agency@marketmyspec.test` (agency account owner, QA Agency).
- Navigated to `http://localhost:4008/agency`.
- Page renders "Client Dashboard" with subtitle "Accounts your agency manages".
- One client row visible: "Journey4 Client Corp" with "Account Manager" access level and an "Enter" button.
- URL remained at `/agency` — no redirect.

Evidence: s01-agency-dashboard-agency-user.png

### Scenario 2b: Individual-account user cannot access /agency

PASS

- Signed in as `qa-client@marketmyspec.test` (individual account only — one QA Client Account membership, type: individual).
- Navigated to `http://localhost:4008/agency`.
- Redirected to `http://localhost:4008/accounts`.
- Flash message shown: "You need an agency account to access this page."
- `require_agency_account` on_mount guard correctly blocks individual-account users.

Note: `qa@marketmyspec.test` cannot be used to test this scenario because it has an incidental agency account membership from prior test runs (`mix spex` created fixtures that added qa@ to an agency account in the shared dev DB). `qa-client@` (user_id=7) has only an individual account membership and correctly demonstrates the redirect.

Evidence: s03-agency-route-individual-redirect.png, s04-individual-user-redirect-to-accounts.png

### Scenario 3: Dashboard data-test attributes

PASS

All required data-test attributes are present in the rendered HTML (confirmed via Vibium CSS selector checks on the live page):

| Selector | Expected | Result |
|---|---|---|
| `[data-test='agency-client-dashboard']` | PRESENT | PRESENT |
| `[data-test='client-row']` | PRESENT | PRESENT |
| `[data-test='client-name']` | PRESENT | PRESENT |
| `[data-test='access-level']` | PRESENT | PRESENT |
| `[data-test='client-status']` | ABSENT | ABSENT |
| `[data-test='client-mrr']` | ABSENT | ABSENT |
| `[data-test='client-last-activity']` | ABSENT | ABSENT |

The brief claimed `dashboard.ex` had no data-test attributes — this is superseded. All required attributes are present in the current implementation.

### Scenario 4: BDD spex tests

PASS

All 5 specified spex pass with 0 failures:

```
mix spex test/spex/679_agency_account_type_and_client_dashboard/criterion_5781_agency_user_sees_the_client_management_dashboard_spex.exs
mix spex test/spex/679_agency_account_type_and_client_dashboard/criterion_5782_individual_account_user_cannot_access_the_agency_dashboard_spex.exs
mix spex test/spex/679_agency_account_type_and_client_dashboard/criterion_5791_dashboard_rows_show_name_and_access_level_only_spex.exs
mix spex test/spex/679_agency_account_type_and_client_dashboard/criterion_5795_dashboard_shows_all_client_accounts_with_name_and_access_level_spex.exs
mix spex test/spex/679_agency_account_type_and_client_dashboard/criterion_5796_dashboard_variant_with_a_status_column_is_rejected_spex.exs
```

Result: 5 tests, 0 failures. All 249 spex pass (0 failures) as of this run.

Note: The brief stated that fixture functions (`account_fixture/2`, `invited_grant_fixture/3`, `originated_client_fixture/2`, `account_member_fixture/3`) were missing and would cause `UndefinedFunctionError`. These are present and functional — all spex pass without error.

### Scenario 5: Nav link for agency dashboard

PASS

- Signed in as `qa-agency@marketmyspec.test`, navigated to `http://localhost:4008/accounts`.
- `[data-test='nav-agency-dashboard']` is PRESENT and VISIBLE on the accounts page.
- `href` attribute value: `/agency` — points to the correct route.

Note: For `qa-client@` (individual account only), `[data-test='nav-agency-dashboard']` is NOT visible on `/accounts` — the nav link is conditional on agency account membership.

Evidence: s05-accounts-nav-agency-link.png

## Evidence

- `.code_my_spec/qa/679/screenshots/s01-agency-dashboard-agency-user.png` — agency dashboard rendered at /agency for qa-agency@ user, showing client row for "Journey4 Client Corp"
- `.code_my_spec/qa/679/screenshots/s03-agency-route-individual-redirect.png` — /agency URL still in bar after navigation for qa-client@, before redirect completes
- `.code_my_spec/qa/679/screenshots/s04-individual-user-redirect-to-accounts.png` — /accounts page with flash "You need an agency account to access this page." after redirect
- `.code_my_spec/qa/679/screenshots/s05-accounts-nav-agency-link.png` — /accounts page for qa-agency@ showing nav-agency-dashboard link pointing to /agency
- `.code_my_spec/qa/679/screenshots/s06-agency-dashboard-404.png` — 404 error for /agency/dashboard (route does not exist)

## Issues

### /agency/dashboard returns 404 — brief's pre-condition note was incorrect

#### Severity

INFORMATIONAL

#### Description

The brief stated "The router currently maps to `/agency/dashboard`" and listed this as a route mismatch bug. In fact, the router mounts the dashboard at `/agency` (not `/agency/dashboard`). `/agency/dashboard` returns 404. The BDD specs all navigate to `/agency`, which is the correct and implemented route. No fix required — the brief's pre-condition notes were describing a state that no longer exists (or never existed in the codebase at time of QA).

### qa@ test user has incidental agency membership from prior spex runs

#### Severity

LOW

#### Description

`qa@marketmyspec.test` (user_id=1) has an agency account membership in the dev DB from prior `mix spex` test fixture runs. This means `qa@` passes the `require_agency_account` guard and can access `/agency`. The seeds describe `qa@` as an individual-account user, but the DB state differs. This does not affect production behavior (test DB pollution only) but makes `qa@` unsuitable for testing the individual-user redirect scenario. Used `qa-client@marketmyspec.test` instead for Scenario 2b.
