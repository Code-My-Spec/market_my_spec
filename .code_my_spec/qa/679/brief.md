# QA Brief: Story 679 — Agency Account Type And Client Dashboard

## Tool

web (Vibium MCP browser tools for all LiveView page interactions)

## Auth

Run the QA seed script to create a seeded user and print a magic-link URL:

```
mix run priv/repo/qa_seeds.exs
```

Navigate Vibium to the magic-link URL printed by the seed script to sign in as `qa@marketmyspec.test`.

The server is running at **http://localhost:4008** (port 4007 is stale — confirmed via `/auth/github` returning 404 on 4007 vs 302 on 4008).

## Seeds

Run the base seed to create the QA user:

```
mix run priv/repo/qa_seeds.exs
```

Note: Most story 679 scenarios require agency-typed accounts, fixture helpers for `invited_grant_fixture`, `originated_client_fixture`, and `account_member_fixture`, and a `/agency/clients/new` form. These are exercised via the `mix spex` test runner for scenarios that depend on in-process test fixtures. Browser testing is used for what is accessible via the running app.

## What To Test

### Scenario 1: Route existence check — /agency vs /agency/dashboard

Verify whether the route `/agency` exists or only `/agency/dashboard` exists:

- Navigate to `http://localhost:4008/agency` while authenticated as the QA user
- Observe: does it 404, redirect, or render?
- Navigate to `http://localhost:4008/agency/dashboard` while authenticated
- Observe: does it render the client dashboard page?
- BDD specs all use `/agency` — the router currently maps to `/agency/dashboard`. This is a route mismatch bug.

Expected: `/agency` should resolve to the agency dashboard (per all BDD specs); currently 404.

### Scenario 2: Agency dashboard renders for agency-typed account

This requires an agency-typed account. The QA user (`qa@marketmyspec.test`) has an individual account by default.

- Sign in as QA user via magic-link
- Navigate to `http://localhost:4008/agency/dashboard`
- Observe what renders (redirect for individual accounts, or the dashboard)

Expected per spec (criterion 5782): individual-account users should be redirected away from the agency dashboard, not shown it.

### Scenario 3: Dashboard data-test attributes

Navigate to `http://localhost:4008/agency/dashboard` while authenticated as an agency user (if possible via seeding).

Check for the presence of required `data-test` attributes in the rendered HTML:
- `[data-test='agency-client-dashboard']` — required by criterion 5781
- `[data-test='client-row']` — required by multiple criteria
- `[data-test='client-name']` and `[data-test='access-level']` on each row
- Absence of `[data-test='client-status']`, `[data-test='client-mrr']`, `[data-test='client-last-activity']`

Expected: The current `dashboard.ex` source has NO `data-test` attributes at all.

### Scenario 4: Run BDD spex tests to enumerate failures

Run each spex file and capture the failure output for systematic issue reporting:

```
mix spex test/spex/679_agency_account_type_and_client_dashboard/criterion_5781_agency_user_sees_the_client_management_dashboard_spex.exs
mix spex test/spex/679_agency_account_type_and_client_dashboard/criterion_5782_individual_account_user_cannot_access_the_agency_dashboard_spex.exs
mix spex test/spex/679_agency_account_type_and_client_dashboard/criterion_5791_dashboard_rows_show_name_and_access_level_only_spex.exs
mix spex test/spex/679_agency_account_type_and_client_dashboard/criterion_5795_dashboard_shows_all_client_accounts_with_name_and_access_level_spex.exs
mix spex test/spex/679_agency_account_type_and_client_dashboard/criterion_5796_dashboard_variant_with_a_status_column_is_rejected_spex.exs
```

### Scenario 5: Check nav link for agency dashboard

Navigate to `http://localhost:4008/accounts` and look for `[data-test='nav-agency-dashboard']` link (mentioned in story 678 fixes as a placeholder hook).

Expected: the nav link exists and points to the agency dashboard.

## Setup Notes

The dev server is on port **4008** (not 4007 — 4007 is serving stale code from a prior run and returns 404 on `/auth/github`).

The BDD specs reference the following fixture functions that do NOT exist in `MarketMySpecSpex.Fixtures` or `MarketMySpec.UsersFixtures`:
- `Fixtures.account_fixture/2`
- `Fixtures.invited_grant_fixture/3`
- `Fixtures.originated_client_fixture/2`
- `Fixtures.account_member_fixture/3`

These missing fixtures cause `UndefinedFunctionError` in multiple spex tests.

The dashboard source at `lib/market_my_spec_web/live/agency_live/dashboard.ex` has no `data-test` attributes and hardcodes `client_accounts: []` in mount (always empty). The `AgencyLive.Dashboard` LiveView is essentially a skeleton.

The router mounts the agency dashboard at `/agency/dashboard` but all 13 BDD specs navigate to `/agency`. This is the primary route mismatch.

## Result Path

`.code_my_spec/qa/679/result.md`
