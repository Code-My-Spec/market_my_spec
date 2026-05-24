defmodule MarketMySpec.Journeys.Journey6UatTest do
  @moduledoc """
  Journey 6 (UAT, brew binary) — install + pair + dispatch + Offline + fallback.

  Driven by `MarketMySpecWeb.JourneyCase` with `env: :uat`. The Wallaby
  session is pre-loaded with the captured UAT session cookies (see
  `.code_my_spec/qa/sessions/SETUP.md`), and the MCP side runs through
  `Anubis.Client` so the test exercises the real bearer-auth + JSON-RPC
  + tools/call transport — not just the in-process tool module.

  ## Preconditions

    * `~/.mms-agent/auth.uat.json` exists from a prior `mms-agent --env uat pair`
      (this test doesn't drive pairing — that's a one-time human-mediated
      step; covered separately by the manual half of Journey 6)
    * `.code_my_spec/qa/sessions/uat.json` exists and is current
    * `mms-agent` is on PATH (brew install)
    * UAT is reachable

  ## How to run

      mix test --include journey --include uat test/journeys/journey_6_uat_test.exs
  """

  use MarketMySpecWeb.JourneyCase, env: :uat

  alias Wallaby.Browser
  alias Wallaby.Query

  @moduletag :journey
  @moduletag :uat

  feature "Journey 6 — paired binary serves dispatch; goes Offline + falls back when killed",
          %{session: session, env: env} do
    # --- Step 5–6: confirm the binary is Online on /agents ------------
    # This assumes you've started `mms-agent --env uat server` in another
    # terminal. The pair flow itself is human-mediated and runs separately.
    {:ok, _agent_port} = JourneyHelpers.start_agent_binary(env)
    # Give the channel client a beat to connect + join + register presence
    Process.sleep(3_000)

    session
    |> Browser.visit("/agents")
    |> Browser.assert_has(Query.text("Online"))

    # --- Step 7: dispatch a search through the agent ------------------
    {:ok, bearer} = JourneyHelpers.mint_bearer(session, env)
    {:ok, client} = JourneyHelpers.start_mcp_client(env, bearer, name: :journey_6_uat_client)

    {:ok, online_response} =
      JourneyHelpers.call_tool(client, "search_engagements", %{"query" => "elixir"})

    refute Map.has_key?(online_response, "notices"),
           "expected dispatch through online agent (no notices entry), got: #{inspect(online_response)}"

    candidates = Map.get(online_response, "candidates", [])
    assert length(candidates) > 0, "expected at least one candidate from online dispatch"

    # --- Step 8: kill the binary; /agents flips Offline ---------------
    JourneyHelpers.kill_agent_binary()
    # Phoenix.Presence diff broadcast lands within ~5s of the socket
    # tearing down. Give it a little headroom.
    Process.sleep(7_000)

    session
    |> Browser.visit("/agents")
    |> Browser.assert_has(Query.text("Offline"))

    # --- Step 9: dispatch with no agent returns the fallback notice ---
    {:ok, offline_response} =
      JourneyHelpers.call_tool(client, "search_engagements", %{"query" => "elixir"})

    notices = Map.get(offline_response, "notices", [])

    assert Enum.any?(notices, &String.contains?(&1, "Pair or start")),
           "expected fallback notice mentioning Pair or start, got notices: #{inspect(notices)}"
  end
end
