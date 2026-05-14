# Use ReqCassette for HTTP Recording in Req-Based Tests; Keep ExVCR for Legacy HTTPoison Code

## Status
Accepted

## Context
The project already has `{:req_cassette, "~> 0.6.0", only: :test}` in `mix.exs` and an existing `exvcr.md` ADR that accepts ExVCR for all external HTTP recording. The Engagements context uses Req (see `req.md` ADR). ReqCassette is purpose-built for Req: it integrates via `Req.Test` and Phoenix's Plug adapter rather than global process mocking, making it safe for `async: true` tests.

ExVCR intercepts HTTPoison/Hackney via a global mock. Applying ExVCR to Req-based code would require either using it in a non-async mode or fighting its architecture. ReqCassette and ExVCR operate on different HTTP clients and can coexist.

## Decision
ReqCassette is the recorder for all Req-based HTTP code (Engagements context). ExVCR remains the recorder for all HTTPoison-based code (PowAssent OAuth integrations, ExAws indirect calls).

**Migration boundary:**
- `Engagements.Reddit.*` tests — ReqCassette (`with_cassette/2`)
- `Engagements.Discourse.*` tests — ReqCassette
- Existing PowAssent strategy tests — ExVCR (unchanged)
- ExAws/SSM calls in `Secrets` — already covered by ExVCR; no change

**Cassette storage:** `test/cassettes/` committed to git, with auth headers filtered before recording (`filter_request_headers: ["authorization", "user-api-key", "user-api-client-id"]` in config).

**CI / `mix spex`:** Global default mode is `:replay` via `config/test.exs`. Cassettes are re-recorded locally when the upstream API changes, then committed.

## Consequences
- Async-safe test isolation for all new Engagements tests without restructuring ExVCR cassettes.
- Two recording libraries coexist; developers must know which context uses which. The rule is simple: Req code uses ReqCassette, HTTPoison code uses ExVCR.
- The existing `exvcr.md` ADR is not modified; this ADR narrows its scope by establishing ReqCassette as the alternative for Req.
- If HTTPoison is removed from the project in a future cleanup, ExVCR can be removed at that point and this ADR updated.
