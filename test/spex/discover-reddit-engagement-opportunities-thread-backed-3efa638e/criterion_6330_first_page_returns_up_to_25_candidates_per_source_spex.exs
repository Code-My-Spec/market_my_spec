defmodule MarketMySpecSpex.Story705.Criterion6330Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6330 — First page returns up to 25 candidates per source.

  Single Reddit venue with 25 cassette children → response carries
  exactly 25 candidates. The adapter caps the listing fetch at limit=25
  (encoded in the cassette URI).

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

  spex "first page returns up to 25 candidates per source" do
    scenario "25-thread cassette yields exactly 25 candidates from a single venue" do
      given_ "a venue and a 25-thread cassette", context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        threads =
          for i <- 1..25 do
            %{
              title: "Thread #{i}",
              score: 26 - i,
              num_comments: i,
              id: "t#{i}",
              permalink: "/r/elixir/comments/t#{i}/_/"
            }
          end

        RedditHelpers.build_search_cassette!("crit_6330_cap",
          subreddit: "elixir",
          query: "elixir",
          children: threads
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6330_cap", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the candidate list contains exactly 25 entries", context do
        candidates = context.payload["candidates"]
        assert length(candidates) == 25,
               "expected 25 candidates from a single venue, got #{length(candidates)}"

        {:ok, context}
      end
    end
  end
end
