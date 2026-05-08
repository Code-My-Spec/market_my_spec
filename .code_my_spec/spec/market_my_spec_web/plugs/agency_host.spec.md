# MarketMySpecWeb.Plugs.AgencyHost

Endpoint plug that reads the request host. If the host is `<slug>.marketmyspec.com` and an agency currently claims that subdomain, attaches the agency to the conn for downstream LiveViews. Apex requests pass through unchanged. Unrecognized subdomains redirect to the apex. API endpoints (`/oauth/*`, `/mcp`, `/.well-known/*`) are skipped — they remain apex-only.

## Type

module

## Dependencies

- MarketMySpec.Agencies
