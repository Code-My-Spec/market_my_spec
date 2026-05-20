# MarketMySpecAgent

Self-contained Burrito binary installed on a user's machine, paired to their MMS account via the OAuth `agent:connect` scope. Its purpose is to execute HTTP operations (Reddit read/write today) from a residential IP, since MMS-server-originated traffic is blocked by those platforms. On first run, the user pairs the binary to their account through a browser-based OAuth-style consent flow managed by `MarketMySpecAgent.Pairing`; credentials are persisted to `~/.mms-agent/auth.json` (mode 0600) and cached in `Auth.Store`. Once paired, the binary maintains a long-lived Slipstream connection to the server channel (`agents:<user_id>`), accepts `http_request` envelopes from `MarketMySpec.Agents.Dispatcher`, replays them through Req against the host allowlist (reddit.com, oauth.reddit.com), and posts `http_response` envelopes back. Packaged via Burrito and distributed via Homebrew; it is not part of the `:market_my_spec` server release.

## Type

context

## Dependencies

- MarketMySpec
