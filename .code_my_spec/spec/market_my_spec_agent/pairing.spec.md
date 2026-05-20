# MarketMySpecAgent.Pairing

First-run browser-based pairing flow. `run/1` is the single public entry point; it blocks until the user approves, denies, or the listener times out (5 minutes), then returns `:ok`, `{:error, :denied}`, or `{:error, :timeout}`. Internally: (1) generates a single-use state token with at least 128 bits of entropy (`:crypto.strong_rand_bytes/1` base64-encoded); (2) binds an ephemeral TCP port on `{127, 0, 0, 1}` by letting the OS assign port 0, then reads the actual port back — this avoids conflicts and prevents guessing; (3) starts a one-shot Bandit + Plug listener on that port at `/callback`; (4) opens the browser at `<server_url>/agents/pair?state=<state>&port=<port>&name=<agent_name>` using a platform-specific command (`open` on macOS, `xdg-open` on Linux, `start` on Windows) — the `:open_browser` option accepts a `fun/1` override for testing; (5) blocks waiting for the callback — the callback Plug extracts either `?token=<token>` (success path) or `?denied=true` (denial path) from the query string and sends the result to the blocked caller via a message or a one-shot `GenServer.reply`. On token receipt, builds a credential map (`%{"agent_id" => ..., "token" => ..., "server_url" => ..., "paired_at" => ...}`) and calls `Auth.Store.put/1`. The URL params (`state`, `port`, `name`) and the callback shape (`?token=` and `?denied=true`) are defined by the server-side pairing protocol in `MarketMySpec.Agents.Pairing` and `MarketMySpecWeb.AgentLive.Pair`; the binary only consumes them. Options accepted by `run/1`: `:server_url` (defaults to `MarketMySpecAgent.Config.server_url/0`), `:agent_name` (defaults to `:inet.gethostname/0` result), `:open_browser` (defaults to OS shell invocation).

## Type

module

## Dependencies

- MarketMySpecAgent.Auth.Store
