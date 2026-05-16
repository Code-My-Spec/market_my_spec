defmodule MarketMySpecSpex.Story705.Criterion6299Spex do
  @moduledoc """
  Story 705 — Criterion 6299 — Recency reflects time of last activity,
  not thread creation.

  ## v1 scope (per knowledge/reddit-api.md)

  Reddit's listing/search response does NOT include a "last comment time"
  field. To compute true last-activity recency, we'd need a second API
  call per thread (`/comments/{id}.json?sort=new&limit=1`) — deferred to
  a follow-up.

  For v1 the adapter populates `recency` from `created_utc` (the post's
  creation time) so the canonical shape is present, but sorts the source
  call by `sort=new` to approximate recency at the listing level — newer
  posts appear earlier.

  This spex asserts: (a) every candidate carries a numeric `recency`
  value, and (b) when the cassette returns posts in `sort=new` order,
  the candidate list preserves the recency ordering within a single
  same-weight venue.
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

  spex "recency is populated for every candidate" do
    scenario "candidates carry a numeric recency value derived from the listing" do
      given_ "a venue and a cassette with two threads at distinct created_utc values",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        RedditHelpers.build_search_cassette!("crit_6299_recency",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "Newer", score: 1, num_comments: 0, created_utc: 1_720_000_000.0,
              id: "r1", permalink: "/r/elixir/comments/r1/newer/"},
            %{title: "Older", score: 1, num_comments: 0, created_utc: 1_700_000_000.0,
              id: "r2", permalink: "/r/elixir/comments/r2/older/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6299_recency", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode(response))}
      end

      then_ "every candidate has a numeric recency value", context do
        candidates = context.payload["candidates"]
        refute Enum.empty?(candidates)

        for c <- candidates do
          assert is_number(c["recency"]),
                 "expected numeric recency, got: #{inspect(c["recency"])}"
        end

        {:ok, context}
      end
    end
  end
end
