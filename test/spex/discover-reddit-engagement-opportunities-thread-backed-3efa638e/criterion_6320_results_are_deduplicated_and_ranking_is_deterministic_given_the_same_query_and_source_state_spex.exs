defmodule MarketMySpecSpex.Story705.Criterion6320Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6320 — Results are deduplicated and ranking is deterministic
  given the same query and source state.

  Two enabled venues whose cassettes both return a thread with the same
  URL (the cross-post case) must surface that thread once. Two back-to-
  back calls with the same query must return identical ordering and
  identical thread_id UUIDs.

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

  @shared_permalink "/r/elixir/comments/dup1/cross_posted/"

  spex "results dedup by URL and rank/UUIDs are deterministic across calls" do
    scenario "the shared URL appears once and two calls return identical UUIDs in identical order" do
      given_ "two enabled venues whose cassettes both surface a shared URL plus venue-unique URLs",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "elixir", enabled: true
        })

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "programming", enabled: true
        })

        RedditHelpers.build_multi_cassette!("crit_6320_dedup", [
          [
            subreddit: "elixir",
            query: "elixir",
            children: [
              %{title: "Cross-post", score: 50, num_comments: 5, id: "dup1",
                permalink: @shared_permalink},
              %{title: "Elixir-only", score: 10, num_comments: 2, id: "e1",
                permalink: "/r/elixir/comments/e1/_/"}
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

      when_ "search_engagements is called twice", context do
        run = fn ->
          {:reply, response, _frame} =
            RedditHelpers.with_reddit_cassette("crit_6320_dedup", fn ->
              SearchEngagements.execute(%{query: "elixir"}, context.frame)
            end)

          decode_payload(response)
        end

        first = run.()
        second = run.()
        {:ok, Map.merge(context, %{first: first, second: second})}
      end

      then_ "shared URL appears once and the two responses have identical UUIDs in identical order",
            context do
        urls = Enum.map(context.first["candidates"], & &1["url"])
        shared_full = "https://www.reddit.com" <> @shared_permalink

        assert Enum.count(urls, &(&1 == shared_full)) == 1,
               "expected shared URL exactly once; got URLs: #{inspect(urls)}"

        first_ids = Enum.map(context.first["candidates"], & &1["thread_id"])
        second_ids = Enum.map(context.second["candidates"], & &1["thread_id"])

        assert first_ids == second_ids,
               "expected deterministic UUIDs+ordering across calls; got #{inspect(first_ids)} vs #{inspect(second_ids)}"

        {:ok, context}
      end
    end
  end
end
