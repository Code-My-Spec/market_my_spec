defmodule MarketMySpec.McpServers.AnalyticsAdmin.Tools.ListCustomDimensionsTest do
  use ExUnit.Case, async: true

  alias MarketMySpec.TestRecorder

  @moduledoc """
  Tests for the ListCustomDimensions MCP tool.

  Currently these record/replay against fixture closures rather than
  invoking `ListCustomDimensions.execute/2` directly — they exercise
  cassette shape, not tool behaviour. A real integration test would
  build a Scope with an `active_account.google_analytics_property_id`,
  stub `MarketMySpec.Google.Analytics.list_custom_dimensions/2`, and
  assert on the formatted tool response.

  ## Recording cassettes

  1. Set up a valid Google OAuth integration in your test database.
  2. `RERECORD=1 mix test test/market_my_spec/mcp_servers/analytics_admin/list_custom_dimensions_test.exs`
  3. Subsequent runs replay the recorded `.etf` files.
  """

  describe "execute/2 with recorded responses" do
    test "formats custom dimensions response correctly" do
      result =
        TestRecorder.record_or_replay("analytics_list_custom_dimensions_formatted", fn ->
          {:ok,
           %{
             customDimensions: [
               %{
                 name: "properties/123456/customDimensions/dimension1",
                 displayName: "User Category",
                 parameterName: "user_category",
                 scope: "USER",
                 description: "Category of the user"
               },
               %{
                 name: "properties/123456/customDimensions/dimension2",
                 displayName: "Session Type",
                 parameterName: "session_type",
                 scope: "SESSION",
                 description: "Type of session"
               }
             ]
           }}
        end)

      assert {:ok, response} = result
      assert length(response.customDimensions) == 2
      assert Enum.all?(response.customDimensions, &Map.has_key?(&1, :displayName))
    end

    test "handles empty custom dimensions list" do
      result =
        TestRecorder.record_or_replay("analytics_list_custom_dimensions_empty", fn ->
          {:ok, %{customDimensions: []}}
        end)

      assert {:ok, %{customDimensions: []}} = result
    end

    test "handles API errors" do
      result =
        TestRecorder.record_or_replay("analytics_list_custom_dimensions_error", fn ->
          {:error, %{status: 404, body: "Property not found"}}
        end)

      assert {:error, _} = result
    end
  end
end
