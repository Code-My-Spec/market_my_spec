# MarketMySpec

A marketing-strategy plugin for Claude Code, built on top of [CodeMySpec](https://codemyspec.com).

**Open source under Apache 2.0.** Issues, PRs, deploy-it-yourself all welcome.

## What it is

MarketMySpec is a small Phoenix application that exposes a marketing-strategy skill to Claude Code over MCP. One install command connects an existing Claude Code agent to the server, and the agent walks the user through an eight-step strategy flow: ICP, positioning, channels, content.

The MVP ships:

- Magic-link sign-up and sign-in (no passwords)
- Multi-tenant accounts with admin-provisioned agency tier
- OAuth provider scaffolding (GitHub, Google)
- Two MCP servers (auth, skill content)
- The marketing-strategy skill itself

The strategy intelligence runs in the user's own Claude Code subscription. No token markup. No inference resale.

## Why this repo exists publicly

This is the second product shipped by the [CodeMySpec harness](https://codemyspec.com). The harness wrote the code; I orchestrated. Read the case study for the honest teardown:

- [Market My Spec case study](https://codemyspec.com/case-studies/market-my-spec)
- [MetricFlow case study (the prior teardown)](https://codemyspec.com/case-studies/metric-flow)
- [The Harness Layer (technical thesis)](https://codemyspec.com/blog/the-harness-layer)

The repo is open so the harness's claims can be verified against real shipped code, not just diagrams.

## Getting started

```sh
mix setup
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) from your browser.

## Phoenix conventions

- Phoenix 1.7+ with LiveView
- Boundary-enforced module dependencies
- BDD specs via Spex
- OAuth via the standard `phx.gen.auth` pattern + custom provider scaffolding
- Magic-link confirmations via Resend

## License

Apache License 2.0. See [LICENSE](./LICENSE).

## Status

This is an MVP. It works end to end (sign up, link an account, install the MCP, run the strategy skill). It is not fully stable. Issues and PRs welcome.

## Phoenix learning resources

- Official website: <https://www.phoenixframework.org/>
- Guides: <https://hexdocs.pm/phoenix/overview.html>
- Docs: <https://hexdocs.pm/phoenix>
- Forum: <https://elixirforum.com/c/phoenix-forum>
- Source: <https://github.com/phoenixframework/phoenix>
