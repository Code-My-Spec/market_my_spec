defmodule MarketMySpecSpex.Story705.Criterion6292Spex do
  @moduledoc """
  Story 705 — Criterion 6292 — Search query supports keyword filters;
  venue/subreddit filtering is available as an optional argument.

  Two enabled venues (r/elixir, r/programming). Without the `venue` arg,
  both are queried. With `venue: "elixir"`, only r/elixir is queried —
  the cassette only contains the r/elixir interaction, so a call to
  r/programming would raise a ReqCassette mismatch.
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

  defp decode(%Response{content: parts}) when is_list(parts) do
    parts
    |> Enum.map_join("\n", fn
      %{"text" => t} -> t
      %{text: t} -> t
      other -> inspect(other)
    end)
    |> Jason.decode!()
  end

  spex "venue filtering is an optional arg to search_engagements" do
    scenario "passing venue: \"elixir\" restricts the fan-out to that subreddit" do
      given_ "two enabled venues and a cassette with ONLY the r/elixir interaction",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "programming", enabled: true})

        RedditHelpers.build_search_cassette!("crit_6292_filter",
          subreddit: "elixir",
          query: "phoenix",
          children: [
            %{title: "Phoenix-only result", score: 1, num_comments: 0, id: "p1",
              permalink: "/r/elixir/comments/p1/phoenix_only/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called with venue: \"elixir\"", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6292_filter", fn ->
            SearchEngagements.execute(%{query: "phoenix", venue: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode(response))}
      end

      then_ "only the r/elixir candidate appears (r/programming was never called)", context do
        candidates = context.payload["candidates"]
        assert length(candidates) == 1
        [c] = candidates
        assert c["title"] == "Phoenix-only result"
        assert c["url"] =~ "/r/elixir/"

        {:ok, context}
      end
    end
  end
end
