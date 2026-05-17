defmodule MarketMySpecSpex.Story705.Criterion6322Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6322 — Search query supports keyword filters; venue/subreddit
  filtering is available as an optional argument.

  Account has two enabled venues. Calling search_engagements with
  `venue: "elixir"` restricts the fan-out to just r/elixir — the
  cassette only includes the r/elixir interaction, so a stray call to
  r/programming would cause a ReqCassette mismatch.

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

  spex "venue argument restricts the fan-out to a single subreddit" do
    scenario "venue: \"elixir\" only queries r/elixir even with multiple enabled venues" do
      given_ "two enabled venues; cassette has only the r/elixir interaction",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "programming", enabled: true})

        RedditHelpers.build_search_cassette!("crit_6322_filter",
          subreddit: "elixir",
          query: "phoenix",
          children: [
            %{title: "Phoenix only", score: 1, num_comments: 0, id: "p1",
              permalink: "/r/elixir/comments/p1/phoenix_only/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called with venue: \"elixir\"", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6322_filter", fn ->
            SearchEngagements.execute(%{query: "phoenix", venue: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "only the r/elixir candidate is returned (r/programming never queried)", context do
        candidates = context.payload["candidates"]
        assert length(candidates) == 1
        [c] = candidates
        assert c["title"] == "Phoenix only"
        assert c["url"] =~ "/r/elixir/"

        {:ok, context}
      end
    end
  end
end
