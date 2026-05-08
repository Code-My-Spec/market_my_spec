# QA Brief: Story 695 — Agency Subdomain Assignment and Host Routing

> **Status:** Story is freshly Three-Amigos'd as of 2026-05-07. Implementation
> is not yet in tree. This brief is a forward-looking setup plan for the QA
> agent so it has a real DNS path the moment the host plug lands. Do not
> attempt scenario QA until the implementation ships.

Routes `<slug>.marketmyspec.com` requests into a scoped agency context for
the LiveView surface. API endpoints (`/oauth/*`, `/mcp`, `/.well-known/*`)
stay on the apex.

Behaviour matrix:

| Host                            | Surface             | Notes                                                    |
|---------------------------------|---------------------|----------------------------------------------------------|
| `marketmyspec.com`              | Default platform LV | No agency scope                                          |
| `<known>.marketmyspec.com`      | Agency-scoped LV    | scope = that agency                                      |
| `<unclaimed>.marketmyspec.com`  | 302 to apex         | Slug not currently held by any agency (incl. renamed away) |
| `acme.marketmyspec.com/mcp`     | 404                 | API only on apex                                         |

No stale-history tracking. If an agency renames their subdomain, the old
slug just becomes "unclaimed" and redirects to apex like any other
never-claimed slug. The host plug only checks the live `accounts` table.

## Tool

- `web` (Vibium MCP browser tools) for LiveView host-routing scenarios.
- `curl` for API surface checks (`/mcp`, `/.well-known/*`) — must verify
  these stay on the apex and 404 on subdomains.
- Cloudflare v4 API via `curl` for DNS record lifecycle (create + delete).
- `mix spex` for the schema/changeset/authorization specs that don't need
  real DNS.

## Auth

Run the QA seed script to create a seeded user and print a magic-link URL:

```
mix run priv/repo/qa_seeds.exs
```

Navigate Vibium to the magic-link URL printed by the seed script to sign in
as `qa@marketmyspec.test`. The QA user has an individual account by
default; story 695 also requires agency-typed accounts, so the seed script
(or its extensions for this story) must produce at least two agencies
("Acme Marketing" and "Beta Inc") with the QA user as owner of both, plus
configured subdomains matching the DNS fixtures below.

For UAT browser testing the dev server is on localhost:4008; for the real
DNS path, point Vibium at the UAT host (Hetzner nbg1, 46.225.105.88) once
the deploy lands.

## Seeds

```
mix run priv/repo/qa_seeds.exs
```

The seed script must (after this story's implementation lands) produce:

- QA user as owner of an agency account "Acme Marketing" with subdomain
  `acme-qa`.
- Same QA user as owner of an agency account "Beta Inc" with subdomain
  `beta-qa`.
- A separate individual-typed account for the failure-path test that the
  changeset rejects subdomain claims from individual accounts.

If those fixtures aren't yet in `qa_seeds.exs`, file an issue and pause
QA execution.

### DNS fixtures (Cloudflare)

Real DNS records are required to test in a browser against UAT. John has
the Cloudflare API credentials.

- Zone: `marketmyspec.com`
- Zone id: `ca9564c0c590c9af6e479d7de9440795` (per `reference_hetzner_hosts`)
- UAT host: `46.225.105.88` (nbg1)
- Prod host: `178.156.143.212` (ash) — **do not** create test records here

The QA agent should create a small set of CNAME or A records on the UAT
host and tear them down after the run. Suggested fixtures:

| Subdomain     | Purpose                                                          |
|---------------|------------------------------------------------------------------|
| `acme-qa`     | Active agency subdomain (happy path)                             |
| `beta-qa`     | Second agency, used to verify cross-agency isolation             |
| `ghost-qa`    | Never claimed — must 302 to apex                                 |
| `acme-old-qa` | DNS-only fixture for the rename case — points at UAT but the agency record will not claim it; should also 302 to apex |

Use the `cloudflare-dns-tunnels.md` knowledge doc for the API call shape.
Records can be created and deleted via `curl` against the Cloudflare v4
API with the API token in env. Always set TTL low (60s) so cleanup is
quick.

**Cleanup is mandatory.** Leave no test records behind in the zone.

### Same-domain caveat (John's question)

Testing subdomains under the production zone `marketmyspec.com` is the
correct shape for *this* story — the spec is literally about
`<slug>.marketmyspec.com`. There is no masking concern here as long as:

1. **Session cookies are scoped to the host, not `.marketmyspec.com`.**
   If the app ever sets `Domain=.marketmyspec.com` on cookies, sessions
   leak across all subdomains and same-domain QA will silently pass while
   real isolation is broken. **Verify cookie `Domain` is unset (host-only)
   or explicitly the apex/UAT host before trusting QA results.**
2. **Wildcard TLS cert covers `*.marketmyspec.com`.** If it doesn't, every
   test subdomain throws a TLS warning. Confirm cert SANs include the
   wildcard before running browser flows; otherwise Vibium may bail on
   TLS errors and emit confusing failures.
3. **DNS propagation.** Cloudflare records propagate within ~30s with
   short TTL, but if the QA agent creates and queries within the same
   second, the resolver may still be NXDOMAIN. Sleep 5s after create.

The OTHER story (custom FQDN / CNAME) will need a separate domain John
controls — at that point we'll genuinely need a non-`marketmyspec.com`
host.

## What To Test

Run the spex first, then browser-validate the routing surface:

```
mix spex test/spex/695_*/
```

Then with the QA seeds and DNS records in place, drive Vibium against the
hosts in the matrix above. Capture screenshots of each.

### Browser scenarios

1. **Active subdomain** → `acme-qa.marketmyspec.com`. Expect agency-scoped
   LV; `current_scope.account.id` matches Acme.
2. **Unclaimed subdomain** → `ghost-qa.marketmyspec.com`. Expect 302 to
   `marketmyspec.com`.
3. **Renamed-away subdomain** → seed Acme with subdomain `acme-qa`, rename
   it to a different slug, then hit `acme-qa.marketmyspec.com`. Expect 302
   to apex (same path as the never-claimed case — no special handling).
4. **Apex** → `marketmyspec.com`. Expect default platform LV; no agency
   scope on `current_scope`.
5. **Cross-agency isolation** → sign in as Acme owner, navigate to
   `beta-qa.marketmyspec.com`. Confirm scope flips to Beta and the
   browser does not retain Acme-only session state.
6. **API on subdomain** → `curl -i https://acme-qa.marketmyspec.com/mcp`.
   Expect 404, NOT a 401 from the MCP auth plug (which would mean the
   route is still wired up there).
7. **API on apex** → same `/mcp` call against apex with a valid bearer
   token. Expect normal MCP handling.

### Spex scenarios

The story's spex files will land at
`test/spex/695_agency_subdomain_assignment_and_host_routing/`. They cover:

- subdomain uniqueness, format, reserved-name rejection
- `:manage_account` authorization
- agency-only (individual accounts cannot claim)
- host plug routing (active / unclaimed / apex)
- API-on-apex-only behaviour

Run them all with `mix spex test/spex/695_*/`.

### Note on the individual-account guard

Rule "only agency-typed accounts can claim a subdomain" may not have a
visible UI failure path — the form to set a subdomain probably won't
render for individual accounts at all. The failure-path scenario is still
valid as a model-layer test: hit the changeset directly (or post the
form-action URL) as an individual-account user and confirm the changeset
rejects it. Don't expect a clickable repro.

### If same-domain testing turns out to mask issues

Plausible cases where it would: cookie `Domain=.marketmyspec.com`,
host-stripping middleware, Cloudflare-side caching keyed by zone instead
of host. If any of those surface during testing, ask John to provision a
separate domain (he's offered) and re-run scenarios there to confirm.

## Result path

`.code_my_spec/qa/695/result.md`
