# MarketMySpec.Agents.Dispatcher

Server→agent HTTP request orchestrator. dispatch_http/2 (user, %{method, url, headers, body}, opts) — validates host against HostAllowlist, resolves the target agent via Presence.most_recently_connected/1 on the user's topic (fails fast with {:error, :agent_offline} when no agent is online), broadcasts an http_request envelope tagged with the target agent_id on "agents:<user_id>" via Endpoint, awaits the matching http_response with a default 30s timeout (overridable), and surfaces {:ok, %{status, headers, body}} or {:error, :timeout | :agent_disconnected | :host_not_allowed | reason}. On agent disconnect mid-request, cancels the pending receive and returns :agent_disconnected so callers don't wait out the 30s timeout.

## Type

module
