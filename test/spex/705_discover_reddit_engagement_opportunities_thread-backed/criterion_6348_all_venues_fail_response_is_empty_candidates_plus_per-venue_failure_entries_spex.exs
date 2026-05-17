defmodule MarketMySpecSpex.Story705.Criterion6348Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6348 — All venues fail; response is empty candidates plus
  per-venue failure entries.

  All-fail variant of 6321. Two venues, both return 5xx. Response carries
  empty candidates list + one failure entry per venue. No exception.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  defp decode_payload(%Response{content: parts}) when is_list(parts) do
    parts
    |> Enum.map_join("\n", fn
      %{"text" => t} -> t
      %{text: t} -> t
      other -> inspect(other)
    end)
    |> Jason.decode!()
  end

  spex "all venues fail; response carries empty candidates plus per-venue failure entries" do
    scenario "two enabled venues both 500; candidates empty, failures has both" do
      given_ "two enabled venues whose cassettes both return 500", context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "programming", enabled: true})

        RedditHelpers.build_multi_cassette!("crit_6348_all_fail", [
          [subreddit: "elixir", query: "elixir", status: 500],
          [subreddit: "programming", query: "elixir", status: 500]
        ])

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6348_all_fail", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "empty candidates, two failure entries, no exception", context do
        candidates = context.payload["candidates"]
        failures = context.payload["failures"]

        assert candidates == [],
               "expected empty candidates when every venue fails, got: #{inspect(candidates)}"

        assert length(failures) == 2,
               "expected one failure entry per failed venue, got #{length(failures)}"

        {:ok, context}
      end
    end
  end
end
