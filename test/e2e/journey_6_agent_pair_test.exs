defmodule MarketMySpecWeb.Journeys.Journey6AgentPairTest do
  @moduledoc """
  Journey 6 — Founder installs the MMS Agent, pairs, joins channel, dispatches Reddit search.

  Covers stories: 731 (Install and pair), 732 (Connect and report status),
  733 (Reddit operations via agent).

  Wallaby can't drive this end-to-end. The journey is a 3-process flow:

      ┌──────────┐    pair URL    ┌────────────┐   wss   ┌──────────────┐
      │ browser  │ ─────────────► │  Phoenix   │ ◄─────► │ mms-agent    │
      │ (user)   │ ◄── approve ── │  server    │         │ (burrito)    │
      └──────────┘                └────────────┘         └──────────────┘

  Per-story BDD spex (`test/spex/{731,732,733}_*/`) cover the pieces in
  isolation:

    * 731 — pairing LiveView, token persistence, loopback callback
    * 732 — AgentChannel join, Phoenix.Presence track + diff
    * 733 — Dispatcher.dispatch_http/3, Channel.Client HTTP execution,
            HostAllowlist, anonymous-fallback notice

  This file is a placeholder that documents the manual verification
  procedure. Run the steps in `@moduledoc` of this module by hand when
  shipping a release.

  ## Manual verification procedure

      # Terminal 1 — server
      just server

      # Terminal 2 — agent (in-tree, no burrito)
      just agent
      iex> MarketMySpecAgent.Pairing.run()

      # In the browser:
      #   1. open http://localhost:4007/users/log-in/<token>  (mix run priv/repo/qa_seeds.exs)
      #   2. open /agents — empty list
      #   3. agent's pair flow opens /agents/pair?state=...&port=...&name=...
      #   4. click Approve

      # Back in terminal 2 — agent prints :ok, then:
      ls -l ~/.mms-agent/auth.json     # -rw------- (mode 0600)
      jq . ~/.mms-agent/auth.json      # agent_id, user_id, token, server_url, paired_at

      # /agents in the browser flips to "Online · v0.1.0" without a refresh

      # Reddit dispatch (story 733) — server iex:
      iex> user = MarketMySpec.Users.get_user!(<user_id>)
      iex> MarketMySpec.Agents.Dispatcher.dispatch_http(user, %{
        method: :get,
        url: "https://oauth.reddit.com/r/elixir/about.json",
        headers: [],
        body: ""
      })
      # {:ok, %{status: 200, ...}}

      # Kill the agent — /agents flips to Offline within ~5s via presence_diff.

      # Negative path: with no agent online, call SearchEngagements MCP tool.
      # Response includes:
      #   notices: ["No online MMS Agent. Pair or start an agent at /agents."]
      # plus anonymous-fallback Reddit candidates.

  For the packaged binary (Burrito) form — same procedure, but replace
  `just agent` with `./burrito_out/market_my_spec_agent_macos_m1 pair` /
  `... server`. Only worth doing right before a release; day-to-day QA
  uses the in-tree app.
  """

  use MarketMySpecWeb.FeatureCase, async: false

  @moduletag :manual
  @moduletag :wallaby

  @tag :skip
  feature "Journey 6 is manual — see @moduledoc", %{session: _session} do
    flunk("Journey 6 is manual. See @moduledoc for the verification procedure.")
  end
end
