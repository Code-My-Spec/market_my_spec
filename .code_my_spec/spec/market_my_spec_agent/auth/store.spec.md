# MarketMySpecAgent.Auth.Store

In-memory GenServer cache of the paired credentials. Registered under its own module name. On `init/1`, calls `Auth.read/0`; if credentials are present, the state is the returned map; if any error is returned (missing, unreadable, invalid_json), the state is `nil`. `get/0` (synchronous call) returns `{:ok, creds}` when state is a non-nil map, or `{:error, :unpaired}` when state is `nil`. `put/1` (synchronous call) accepts a credential map, delegates to `Auth.write/1` to persist it to disk, updates the GenServer state to the new map, and returns `:ok`; if `Auth.write/1` raises, the error propagates to the caller and the state is not updated. `put/1` is called exclusively by `MarketMySpecAgent.Pairing` after a successful pairing callback. `Channel.Client` calls `get/0` on each connection attempt to retrieve credentials without touching the filesystem. The store does not broadcast changes to subscribers — readers poll or re-call `get/0` as needed.

## Type

module

## Dependencies

- MarketMySpecAgent.Auth
