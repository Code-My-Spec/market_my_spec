defmodule MarketMySpecSpex.Story705.Criterion6290Spex do
  @moduledoc """
  Story 705 — Criterion 6290 — Results are deduplicated and ranking is
  deterministic given the same query and source state.

  Two enabled venues (r/elixir, r/programming) both return a thread with
  the same URL (a cross-posted link). After fan-out, that thread should
  appear once in the candidate list. Calling search_engagements twice with
  the same query produces byte-identical candidate ordering.
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

  @shared_permalink "/r/elixir/comments/dup1/cross_posted/"

  spex "results are deduplicated and ranking is deterministic" do
    scenario "the same URL surfaced by two venues appears once and ordering repeats" do
      given_ "two enabled venues whose cassettes return a thread with the same URL",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit,
          identifier: "elixir",
          enabled: true
        })

        Fixtures.venue_fixture(scope, %{
          source: :reddit,
          identifier: "programming",
          enabled: true
        })

        RedditHelpers.build_multi_cassette!("crit_6290_dedup", [
          [
            subreddit: "elixir",
            query: "elixir",
            children: [
              %{title: "Cross-post", score: 50, num_comments: 5, id: "dup1",
                permalink: @shared_permalink},
              %{title: "Elixir-only", score: 10, num_comments: 2, id: "e1",
                permalink: "/r/elixir/comments/e1/"}
            ]
          ],
          [
            subreddit: "programming",
            query: "elixir",
            children: [
              %{title: "Cross-post", score: 30, num_comments: 3, id: "dup1",
                permalink: @shared_permalink}
            ]
          ]
        ])

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called twice with the same query", context do
        run = fn ->
          {:reply, response, _frame} =
            RedditHelpers.with_reddit_cassette("crit_6290_dedup", fn ->
              SearchEngagements.execute(%{query: "elixir"}, context.frame)
            end)

          decode(response)
        end

        first = run.()
        second = run.()
        {:ok, Map.merge(context, %{first: first, second: second})}
      end

      then_ "the shared URL appears once and the two calls return the same order", context do
        candidates = context.first["candidates"]
        urls = Enum.map(candidates, & &1["url"])
        shared_full = "https://www.reddit.com" <> @shared_permalink

        assert Enum.count(urls, &(&1 == shared_full)) == 1,
               "expected the shared URL exactly once, got URLs: #{inspect(urls)}"

        first_urls = Enum.map(context.first["candidates"], & &1["url"])
        second_urls = Enum.map(context.second["candidates"], & &1["url"])

        assert first_urls == second_urls,
               "expected deterministic ordering across calls; got: #{inspect(first_urls)} vs #{inspect(second_urls)}"

        {:ok, context}
      end
    end
  end
end
