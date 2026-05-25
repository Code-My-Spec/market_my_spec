defmodule MarketMySpec.Journeys.Journey6UatSmokeTest do
  @moduledoc """
  Foundational smoke test for `MarketMySpecWeb.JourneyCase`.

  Validates the absolute minimum:
    1. The saved UAT session at `.code_my_spec/qa/sessions/uat.json`
       restores into a Wallaby session
    2. That session can navigate UAT and load an auth-required page
    3. The `/agents` page renders the currently-paired binary

  No MCP, no OAuth, no binary lifecycle. If this fails the bigger
  Journey 6 test has zero chance.

      mix test --include journey --include uat test/journeys/journey_6_uat_smoke_test.exs
  """

  use MarketMySpecWeb.JourneyCase, env: :uat

  alias Wallaby.Browser
  alias Wallaby.Query

  @moduletag :journey
  @moduletag :uat

  feature "restored UAT session loads /agents and reads the agent row",
          %{session: session} do
    # Sanity: the session cookie restored from uat.json is present.
    cookies = Wallaby.Browser.cookies(session)
    assert Enum.any?(cookies, &(&1["name"] == "_market_my_spec_key")),
           "expected the restored UAT session cookie to be present"

    session
    |> Browser.visit("/agents")
    |> Browser.assert_has(Query.text("Agents"))
  end
end
