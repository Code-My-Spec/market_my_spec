# MarketMySpecWeb.AgentLive.Pair

Pairing approval screen. Reached when the user's binary opens a browser at /agents/pair?state=...&port=...&name=.... Authenticated user sees a consent prompt ("Pair MMS Agent &lt;name&gt; to your user? It will be able to proxy HTTP requests on your behalf to allowed hosts (reddit.com, oauth.reddit.com)"). On approve: calls Agents.Pairing.complete_pairing/3, redirects browser to http://localhost:&lt;port&gt;/callback?token=... so the binary's local listener captures the token, then shows a "you can close this tab" confirmation. On deny: shows cancellation, no token issued. The pairing binds the agent to the user; account membership is many-to-many on user and not part of the pairing.

## Type

liveview
