# MarketMySpec.Agents.AgentsRepository

User-scoped CRUD over Agent records. list_agents/1 (per user), get_agent/2 (user-scoped fetch), create_agent/3 (user_id + name → new Agent with issued token), revoke_agent/2 (marks revoked, clears token), touch_last_seen/2 (called from Presence hooks). Rejects cross-user access with not-found.

## Type

module
