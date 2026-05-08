# QA Brief: Story 691 — Agency Branding Configuration

## Tool

`web` (Vibium MCP browser tools) for all UI/LiveView scenarios.
`mix spex` for automated contract coverage of all 12 criteria.

## Auth

Run the QA seed script to create the agency owner user and print a magic-link URL:

```
mix run priv/repo/qa_seeds.exs
```

The agency-account owner is `qa-agency@marketmyspec.test`. Use the magic-link
URL printed under "Journey 4 user" to sign in without email. Navigate Vibium to
that URL:

```
http://localhost:4008/users/log-in/<token>
```

After navigating to the magic-link, you land on the authenticated dashboard.
Navigate to `http://localhost:4008/agency/settings` to reach the settings page.

For member-role testing: create a second user (Bob) in the agency as a
`member`-role user. See seed details below.

## Seeds

```
mix run priv/repo/qa_seeds.exs
```

This creates:
- `qa-agency@marketmyspec.test` — agency account owner (Journey 4)
  Agency: "QA Agency" with owner role
- `qa-client@marketmyspec.test` — client account (Journey 5)

For the member-role scenario (criterion 6015), the spex test creates its own
fixtures in the test DB. No extra seed is needed for the browser-based test of
the member guard — the mount redirect happens before the form renders, and
can be validated via the spex directly.

For subdomain-based visitor scenarios (criteria 6021-6025), the spex tests use
`Phoenix.ConnTest.build_conn()` with `Map.put(:host, ...)` to simulate subdomains
in the test DB. No real DNS or subdomain setup is needed for these spex tests.

For browser-based subdomain testing, the `AgencyHost` plug reads the request `Host`
header. Use `curl -H "Host: acme.marketmyspec.com"` to simulate subdomain requests
against the dev server at `localhost:4008`.

## What To Test

### Scenario 1: Owner accesses the settings page

1. Run `mix run priv/repo/qa_seeds.exs` and note the agency magic-link URL
2. Navigate Vibium to `http://localhost:4008/users/log-in/<token>`
3. Navigate to `http://localhost:4008/agency/settings`
4. Verify the page loads with two forms: `[data-test='subdomain-form']` and `[data-test='branding-form']`
5. Verify the branding form has fields: Logo URL (HTTPS), Primary color, Secondary color
6. Capture a screenshot of the initial settings page state

### Scenario 2: Owner saves all three branding fields (criterion 6014)

1. On the settings page, fill the branding form:
   - Logo URL: `https://qa-agency.example/logo.svg`
   - Primary color: `#22c55e`
   - Secondary color: `#1d4ed8`
2. Click "Save branding"
3. Verify a flash success message "Branding saved" appears
4. Reload the page (`http://localhost:4008/agency/settings`)
5. Verify the form is prefilled with the saved values
6. Capture a screenshot showing the prefilled form after save

### Scenario 3: HTTP-only logo URL is rejected (criterion 6017)

1. On the settings page branding form, enter `http://acme.example/logo.svg` as logo URL
2. Submit the form
3. Verify an error message appears containing "must be HTTPS" (or equivalent)
4. Verify the URL was NOT saved (reload and confirm the field does not show the http URL)
5. Capture a screenshot of the validation error

### Scenario 4: Malformed logo URL is rejected (criterion 6018)

1. On the settings page branding form, enter `not-a-url` as logo URL
2. Submit the form
3. Verify an error message appears containing "invalid url" or "must be a valid URL" (case-insensitive)
4. Verify the malformed URL was NOT saved
5. Capture a screenshot of the validation error

### Scenario 5: Valid hex colors are accepted (criterion 6019)

1. On the settings page branding form, enter:
   - Primary color: `#22c55e`
   - Secondary color: `#1d4ed8`
2. Submit the form
3. Verify success — no error messages about color format
4. Reload and verify colors are prefilled

### Scenario 6: Malformed color is rejected (criterion 6020)

1. On the settings page branding form, enter `blue` as primary color
2. Submit the form
3. Verify an error message appears mentioning `#rrggbb`, `hex`, or "invalid color"
4. Verify `blue` was NOT saved as the primary color
5. Capture a screenshot of the color validation error

### Scenario 7: Member-role user cannot access branding settings (criterion 6015)

This is tested via spex (see `mix spex` results). The mount-level guard
in `AgencyLive.Settings` redirects non-`:manage_account` users before
the form renders. Verify via spex run.

### Scenario 8: Visitor on configured subdomain sees branding (criterion 6021)

Test via spex (subdomain simulation using test conn with modified `host`).
Also verify with curl against the dev server:

```
# First set subdomain via the settings form in Vibium, then:
curl -s -H "Host: qa.marketmyspec.com" http://localhost:4008/ | grep -i "primary_color\|agency-navbar-logo"
```

Note: the `AgencyHost` plug only recognizes hosts ending in `.marketmyspec.com`.
For local testing, the spex uses `build_conn |> Map.put(:host, "acme.marketmyspec.com")`
which bypasses the plug entirely (it runs at Endpoint level). Full end-to-end
subdomain routing is exercised by the spex tests.

### Scenario 9: Visitor on apex sees default theme (criterion 6023)

Verify via spex. Also verify via browser:

1. Navigate to `http://localhost:4008/` (apex, no subdomain)
2. Verify there is NO `[data-test='agency-navbar-logo']` element
3. Verify no agency-specific color CSS variables appear in the page source
4. Capture a screenshot of the apex home page

### Scenario 10: Run all spex for story 691

```
for f in test/spex/691_agency_branding_configuration/*_spex.exs; do mix spex "$f"; done
```

All 12 criteria spex must pass green.

## Result Path

`.code_my_spec/qa/691/result.md`

## Setup Notes

The `AgencyHost` plug is an Endpoint-level plug that intercepts requests based
on the `Host` header. In the local dev environment at `localhost:4008`, the
host is always `localhost` — the plug's `classify_host/1` function sees it
as `:unrelated` (not matching `marketmyspec.com`) and passes through without
assigning `current_agency`. This means:

- Browser testing at `localhost:4008` does NOT exercise the subdomain routing path.
- Subdomain-based branding scenarios (criteria 6021-6025) are fully covered by
  the spex suite using `Phoenix.ConnTest.build_conn |> Map.put(:host, ...)`.
- The spex tests confirm that when `current_agency` IS set (via the plug or test
  conn), the `Layouts.marketing` component correctly renders the agency's colors
  and logo in the navbar slot.

For real end-to-end subdomain testing in a browser, the UAT host
(`acme-qa.marketmyspec.com` pointing to 46.225.105.88) would be required.
That is a story 695 concern; story 691 branding rendering is fully covered
by the spex.
