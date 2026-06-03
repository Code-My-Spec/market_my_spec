# MarketMySpec.Agents.Pairing

Pairing protocol. Binary opens browser at MMS /agents/pair?state=...&port=...; authenticated user approves; Pairing.complete_pairing/3 (scope, state, agent_name) creates an Agent via AgentsRepository, returns the plaintext token once, and the AgentLive.Pair surface redirects the browser to the binary's localhost callback to deliver it. start_pairing/2 (scope, params) validates the state token. Verifies state freshness and callback host (localhost only) to prevent token exfiltration.

## Type

module

## Dependencies

- MarketMySpec.Agents
- MarketMySpec.Agents.AgentsRepository
