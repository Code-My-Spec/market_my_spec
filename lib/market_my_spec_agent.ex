defmodule MarketMySpecAgent do
  @moduledoc """
  Locally-installed MMS Agent binary.

  Runs on a user's machine, paired to their MMS account via the OAuth
  `agent:connect` scope. Its purpose is to execute operations (Reddit
  read/write today) from a residential IP that MMS-server-originated
  traffic can't reach without getting blocked.

  Lifecycle:

  1. **Pair** — `MarketMySpecAgent.Pairing.run/1` generates a single-use
     state token, picks a free loopback port, opens
     `https://<mms>/agents/pair?state=...&port=...&name=...` in the
     browser, listens on `localhost:<port>/callback`, and persists the
     issued token to `~/.mms-agent/auth.json` (mode 0600).

  2. **Connect** — once paired, joins its server channel (`agent:<id>`)
     and waits for HTTP request envelopes from `MarketMySpec.Agents.Dispatcher`.

  3. **Execute** — replays envelopes through Req against the host
     allowlist (reddit.com, oauth.reddit.com).

  Packaged as a self-contained Burrito binary; distributed via Homebrew.
  """

  use Boundary, top_level?: true, deps: [MarketMySpec], exports: :all
end
