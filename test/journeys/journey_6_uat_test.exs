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

  @moduletag :journey
  @moduletag :uat

  feature "Journey 6 — paired binary serves dispatch; goes Offline + falls back when killed",
          %{session: session, env: env} do
    # --- Step 5–6: confirm the binary is Online on /agents ------------
    # The pair flow itself is human-mediated and runs separately; this
    # test relies on ~/.mms-agent/auth.uat.json already existing.
    {:ok, log_path} = JourneyHelpers.start_agent_binary(env)

    # Wait for the binary to actually join the channel (burrito extract +
    # BEAM boot + WSS connect + join is 5-12s) rather than a fixed sleep.
    assert :ok == JourneyHelpers.await_agent_joined(log_path),
           "agent binary never joined the channel — see #{log_path}"

    # Presence diff → LiveView update can lag the join by a beat; poll the
    # page rather than asserting on first paint.
    assert JourneyHelpers.wait_for_page_text(session, "/agents", "Online"),
           "agent did not show Online on /agents within the poll window"

    # --- Step 7: dispatch a search through the agent ------------------
    {:ok, bearer} = JourneyHelpers.mint_bearer(session, env)
    {:ok, client} = JourneyHelpers.start_mcp_client(env, bearer, name: :journey_6_uat_client)

    # Ensure at least one Reddit venue exists so search_engagements
    # actually attempts a Reddit dispatch (with no venues there's nothing
    # to dispatch and the online/offline paths can't be distinguished).
    # add_venue is idempotent enough for a test — a dup just errors,
    # which we ignore.
    _ =
      JourneyHelpers.call_tool(client, "add_venue", %{
        "source" => "reddit",
        "identifier" => "elixir"
      })

    {:ok, online_response} =
      JourneyHelpers.call_tool(client, "search_engagements", %{"query" => "elixir"})

    # Deterministic online signal: with the agent proxying the Reddit
    # request from a residential IP, the search completes with NO
    # failures and NO fallback notice. (candidates count is left
    # unasserted — it depends on live Reddit content and would be flaky.)
    assert Map.get(online_response, "failures", []) == [],
           "expected no failures with the agent online, got: #{inspect(online_response)}"

    assert Map.get(online_response, "notices", []) == [],
           "expected no fallback notice with the agent online, got: #{inspect(online_response)}"

    # --- Step 8: kill the binary; /agents flips Offline ---------------
    JourneyHelpers.kill_agent_binary()

    assert JourneyHelpers.wait_for_page_text(session, "/agents", "Offline"),
           "agent did not flip to Offline on /agents after the binary was killed"

    # --- Step 9: with no agent, the Reddit dispatch no longer succeeds --
    # Presence lags the binary's disconnect by a couple seconds before the
    # Dispatcher's online-agent read clears, so retry until the offline
    # behavior shows up. Offline, the server falls back to anonymous direct
    # Reddit access from its datacenter IP, which Reddit 403s — surfacing
    # as a `failures` entry. (See the test moduledoc: the graceful
    # `notices` fallback that story 733 describes does NOT fire on a 403 —
    # tracked as a finding.)
    {:ok, offline_response} =
      JourneyHelpers.call_tool_until(
        client,
        "search_engagements",
        %{"query" => "elixir"},
        fn payload -> Map.get(payload, "failures", []) != [] end
      )

    failures = Map.get(offline_response, "failures", [])

    assert Enum.any?(failures, fn f -> f["source"] == "reddit" end),
           "expected a Reddit failure once the agent is offline, got: #{inspect(offline_response)}"
  end
end
