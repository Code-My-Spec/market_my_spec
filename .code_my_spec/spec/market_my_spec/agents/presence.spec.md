# MarketMySpec.Agents.Presence

Phoenix.Presence wrapper tracking online agents. Topic: "agents:<user_id>" — shared by all paired binaries owned by that user. Metadata: agent_id, version, online_at. agent_online?/1 (agent_id) checks if a specific agent is currently joined. list_online/1 (user) lists online agents for the user. most_recently_connected/1 (user) returns the user's online agent with the latest online_at timestamp — used by Dispatcher to pick a target when multiple agents are online. Drives Dispatcher's offline check and AgentLive.Index's status badges via PubSub on diff.

## Type

module
