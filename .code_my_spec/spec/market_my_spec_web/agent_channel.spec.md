# MarketMySpecWeb.AgentChannel

Phoenix channel handling binary↔server traffic on the per-user topic "agents:<user_id>". All paired binaries owned by a single user share this topic — the channel is one-per-user, not one-per-agent. On join, the binary supplies its agent_id and bearer token in join params; the channel validates against AgentsRepository (matches token_hash + status=:active + agent_id belongs to the user_id from the topic), then registers the agent in Agents.Presence with {agent_id, version, online_at} metadata. Inbound: handles http_response events from a binary and forwards them to the per-request response topic Dispatcher is listening on (the response carries its agent_id so cross-agent stealing is detectable). Outbound: receives http_request events from Dispatcher tagged with a target agent_id; every connected binary on the topic receives the event but only the binary whose agent_id matches processes it — non-targets drop the message. On terminate (disconnect, token revoke), untracks presence and broadcasts cancel events so Dispatcher fails in-flight requests addressed to that agent with :agent_disconnected.

## Type

controller

## Dependencies

- MarketMySpec.Agents
