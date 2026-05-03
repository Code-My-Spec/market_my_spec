# Use Anubis MCP for the MCP server over SSE

## Status
Accepted

## Context
The product hinges on exposing the marketing-strategy skill as MCP resources and tools that the user's Claude Code (or other MCP-aware agent) drives. Story 675 (Skill Behavior Exposed Over MCP (SSE)) requires SSE transport with progressive disclosure — orientation prompt loaded first, step prompts loaded only when reached. Story 674 (Start A Marketing Strategy Interview) requires the agent to kick off and walk an 8-step interview from the user's MCP session.

We need a server-side library that:
- Implements the Model Context Protocol (resources, tools, prompts) end-to-end.
- Speaks the SSE transport (long-lived event stream + POST endpoint), not just stdio.
- Plays well with Phoenix routing and Bandit so we can mount it inside the existing app.
- Supports OAuth-protected requests (the bearer token from `mcp-oauth`).

## Options Considered

- **Anubis MCP (`anubis_mcp`, github: zoedsoupe/anubis-mcp).** Elixir-native MCP server library. Already used in production by CodeMySpec for the same MCP+SSE+OAuth shape this project needs. Active maintainer, integrates with Plug/Phoenix, supports resources/tools/prompts. **Pro:** zero novel ground — match CodeMySpec's working setup. **Con:** GitHub dep, not a polished Hex release; we accept some upstream churn.
- **Hand-rolled MCP server on Bandit + Plug.** Implement the JSON-RPC 2.0 framing, SSE stream, and resource/tool/prompt routing ourselves. **Pro:** zero external surface area. **Con:** large reimplementation cost for a spec that evolves; we'd duplicate work CodeMySpec already absorbed via Anubis.
- **Other Hex options (`mcp_ex`, `hermes_mcp`).** Younger libraries with smaller user bases. **Con:** pulling away from CodeMySpec's stack creates two surface areas to maintain across the two projects.

## Decision
Use `anubis_mcp` (github: zoedsoupe/anubis-mcp), mounted in the Phoenix endpoint behind an OAuth-protected route, for all MCP server functionality. Expose the marketing-strategy skill as MCP resources (orientation, step prompts) and tools (artifact-write callbacks). Match CodeMySpec's wiring so a single mental model covers both MCP servers in the user's stack.

## Consequences
- One MCP server implementation across CodeMySpec and Market My Spec — fixes and patches port one direction.
- Pinning to a GitHub ref means we own the bump cadence; track upstream changes deliberately.
- Skill content (orientation + 8 step prompts) ships as MCP resources, loaded on-demand by the client agent — keeps the client-side context window small and respects progressive disclosure.
- SSE transport requires Bandit (already in deps) and an unbuffered route in the Phoenix pipeline; document this when wiring the endpoint.
