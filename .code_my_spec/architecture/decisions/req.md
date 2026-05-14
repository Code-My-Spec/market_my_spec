# Use Req for HTTP in the Engagements Context

## Status
Accepted

## Context
The engagement-finder feature requires HTTP calls to the Reddit and Discourse (ElixirForum) APIs. The project already lists `{:req, "~> 0.5"}` as a dependency. The existing codebase also uses HTTPoison indirectly via ExAws and the Hackney adapter, and ExVCR covers HTTP test recording for that legacy surface.

Req is the modern, maintained Elixir HTTP client with a composable step/middleware architecture, first-class JSON decode, built-in retry with `Retry-After` support, and a test adapter (`Req.Test`) that makes concurrent test execution safe. HTTPoison is older and requires ExVCR's global-mock approach for test isolation.

## Decision
All HTTP code in the Engagements context — Reddit OAuth token fetch, Reddit search/read/post calls, Discourse topic read, and Discourse reply post — uses Req. Client instances are constructed via factory functions in `MarketMySpec.Engagements.HTTP`, one per source, with the appropriate auth step, User-Agent header, and retry configuration attached at construction time.

No new code outside the Engagements context introduces HTTPoison. ExAws continues to use Hackney as its transport (unchanged).

## Consequences
- Req's plugin-friendly step architecture makes it straightforward to attach per-source OAuth credentials, rate-limit back-off, and cassette recording without modifying call-site code.
- ReqCassette (already in deps) covers test isolation for all Req-based code.
- ExVCR stays in place for HTTPoison-based code (PowAssent/Assent OAuth integrations, ExAws). The two recording systems operate on different HTTP clients and do not conflict.
- If HTTPoison is fully removed in a future refactor, ExVCR can be removed at that point.
