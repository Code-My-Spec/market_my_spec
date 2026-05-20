# MarketMySpecAgent.Channel.Client

Long-lived Slipstream-based Phoenix channel client, registered under its own module name, supervised by `MarketMySpecAgent.Application`. On `init/1`, checks `Auth.Store.get/0`; if unpaired (`{:error, :unpaired}`), schedules a retry with `Process.send_after/3` (default 15s interval) and stays disconnected — no crash, no supervisor churn. When credentials are available, connects to the server's WebSocket endpoint at `<server_url>/socket/agent/websocket` (or equivalent) using the paired `token` as a bearer credential in the join params (`%{"agent_id" => agent_id, "token" => token}`), and joins the topic `"agents:<user_id>"` (the user_id is returned as part of the credential map from `Auth.Store.get/0` after pairing, or derivable from the server's join reply — see `MarketMySpecWeb.AgentChannel`). On a successful join, the client is ready to receive events. Inbound: handles the `"http_request"` event from the channel; the envelope shape is `%{"agent_id" => target_id, "request_id" => id, "method" => method, "url" => url, "headers" => headers, "body" => body}` as defined by `MarketMySpec.Agents.Dispatcher`. Before executing the request, the client checks whether `agent_id` in the envelope matches its own `agent_id` from credentials; if it does not match, the event is dropped silently. If it matches, issues the HTTP request via `Req` with the provided method, URL, headers, and body; assembles a response envelope `%{"agent_id" => agent_id, "request_id" => id, "status" => status, "headers" => headers, "body" => body}`; and pushes it back as an `"http_response"` event on the channel. If the host is not in the allowlist (reddit.com, oauth.reddit.com including subdomains), the request is rejected locally without calling Req, and a response envelope with `status: 403` and a `"body"` of `"host not allowed"` is sent back. On disconnect or channel error, Slipstream's built-in reconnect logic applies; if credentials disappear (e.g. revoke), the next reconnect attempt will fail and the client falls back to the slow-retry unpaired state.

## Type

module

## Dependencies

- MarketMySpecAgent.Auth.Store
