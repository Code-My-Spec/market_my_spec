# Architecture Decisions

Index of all architecture decision records for Market My Spec. Each record captures the context, options considered, decision, and consequences.

## Accepted

### Core stack (pre-made for the standard CodeMySpec stack)

- [Elixir](decisions/elixir.md) — primary language
- [Phoenix](decisions/phoenix.md) — web framework
- [Phoenix LiveView](decisions/liveview.md) — interactive UI
- [Tailwind CSS](decisions/tailwind.md) — styling
- [DaisyUI](decisions/daisyui.md) — component library
- [Dotenvy](decisions/dotenvy.md) — environment management
- [Resend (with Swoosh)](decisions/resend.md) — transactional email
- [phx.gen.auth](decisions/phx-gen-auth.md) — authentication scaffold
- [PowAssent + cms_gen integrations](decisions/pow-assent-integrations.md) — OAuth providers, multi-tenancy, feedback widget
- [Hetzner + Docker Compose](decisions/hetzner-deployment.md) — deployment

### Testing

- [BDD with SexySpex + Wallaby](decisions/bdd-testing.md) — behavior-driven specs
- [Wallaby](decisions/wallaby.md) — browser-based integration tests
- [ExVCR](decisions/exvcr.md) — HTTP recording for HTTPoison-based tests (PowAssent/ExAws)
- [ReqCassette](decisions/req-cassette.md) — HTTP recording for Req-based tests (Engagements context); ExVCR stays for legacy HTTPoison code

### Market My Spec specifics

- [Anubis MCP](decisions/anubis-mcp.md) — MCP server over SSE for skill exposure
- [ex_oauth2_provider](decisions/ex-oauth2-provider.md) — OAuth authorization server for MCP client authentication

### Engagements feature

- [Req](decisions/req.md) — HTTP client for all new code in the Engagements context
- [Reddit integration](decisions/reddit-integration.md) — script app OAuth, password grant, rate-limit back-off, UTM scheme
- [Discourse integration](decisions/discourse-integration.md) — anonymous read, User API Key for posting, ElixirForum trust levels, UTM scheme
