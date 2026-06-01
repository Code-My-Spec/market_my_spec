# Reddit anonymous-fallback fails with HTTP 403; onboarding must require agent pairing

Filed 2026-05-22 from MMS MCP usage during the CodeMySpec marketing cycle. Lower priority — paired agent handles this in practice. This issue captures the onboarding-docs gap.

## Problem

The `search_engagements` MCP tool docstring says:

> When a Reddit venue is searched without an online MMS Agent, the tool falls back to anonymous public Reddit access and includes an informational `notices` list in the payload so the caller knows agent pairing enables authenticated OAuth access.

In practice, the anonymous fallback hits HTTP 403 from Reddit's anti-scraping layer. The failure shape:

```
{"failures": [
  {"source": "reddit", "venue_identifier": "ClaudeAI", "reason": "HTTP error 403"},
  {"source": "reddit", "venue_identifier": "ChatGPTCoding", "reason": "HTTP error 403"},
  ...
]}
```

Confirmed today on prod when the agent was disconnected. After pairing the agent (`/agents` in the MMS web UI), all venues started working as advertised.

## Why it matters

The tool docstring promises a fallback that doesn't function. New operators see "HTTP 403" and don't know that pairing an agent is the actual prerequisite — they assume their venue config is wrong or the server is down.

## Acceptance criteria

Choose one or more:

1. **Update the `search_engagements` docstring** to remove or qualify the anonymous-fallback claim. Replace with: "Reddit venues require a paired MMS Agent. If no agent is online, all Reddit searches fail with HTTP 403 (Reddit anti-scraping). Pair an agent at `/agents` before running Reddit lead-scans."
2. **Emit a clearer error** when the agent is disconnected — instead of bare HTTP 403, return `:agent_required` with a message pointing to `/agents`. The current 403 message reads as a Reddit-side issue, not an MMS configuration issue.
3. **Add an onboarding setup check** — when a new account is created, prompt the operator to pair an agent before they hit their first Reddit search and bounce.

Recommend (1) + (2) at minimum. (3) is nice-to-have.

## Out of scope

- Building a working anonymous fallback. Reddit's anti-scraping is structural; assume agent pairing is required.

## Reference

- Caller-side documentation: `code_my_spec_marketing/marketing/daily/2026-05-22.md` (MMS gap #4)
