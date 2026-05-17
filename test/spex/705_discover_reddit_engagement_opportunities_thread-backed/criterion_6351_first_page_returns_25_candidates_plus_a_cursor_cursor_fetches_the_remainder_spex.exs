defmodule MarketMySpecSpex.Story705.Criterion6351Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6351 — First page returns 25 candidates plus a cursor;
  cursor fetches the remainder.

  Composite of 6330 (25 cap) + 6328 (cursor pagination). Cassette has
  page 1 returning 25 + cursor, page 2 with the cursor returning the
  remaining 5 + nil cursor.

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

  spex "first page returns 25 candidates plus a cursor; cursor fetches the remaining 5" do
    scenario "single venue with 30 threads; page 1 has 25 + cursor; page 2 has 5 + nil cursor" do
      given_ "an enabled r/elixir venue and a cassette with page-1 (25 threads + cursor) and page-2 (5 threads + nil cursor)",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        page1_children =
          for i <- 1..25 do
            %{
              title: "Page 1 — Thread #{i}",
              score: 50 - i,
              num_comments: i,
              id: "p1t#{i}",
              permalink: "/r/elixir/comments/p1t#{i}/_/"
            }
          end

        page2_children =
          for i <- 26..30 do
            %{
              title: "Page 2 — Thread #{i}",
              score: 50 - i,
              num_comments: i,
              id: "p2t#{i}",
              permalink: "/r/elixir/comments/p2t#{i}/_/"
            }
          end

        RedditHelpers.build_multi_cassette!("crit_6351_pagecap", [
          [
            subreddit: "elixir",
            query: "elixir",
            after: nil,
            after_cursor: "t3_p2cursor_6351",
            children: page1_children
          ],
          [
            subreddit: "elixir",
            query: "elixir",
            after: "t3_p2cursor_6351",
            after_cursor: nil,
            children: page2_children
          ]
        ])

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search is called for page 1, then page 2 with the cursor", context do
        {page1, page2} =
          RedditHelpers.with_reddit_cassette("crit_6351_pagecap", fn ->
            {:reply, r1, _f1} = SearchEngagements.execute(%{query: "elixir"}, context.frame)
            p1 = decode_payload(r1)

            {:reply, r2, _f2} =
              SearchEngagements.execute(
                %{query: "elixir", cursor: p1["next_cursor"]},
                context.frame
              )

            {p1, decode_payload(r2)}
          end)

        {:ok, Map.merge(context, %{page1: page1, page2: page2})}
      end

      then_ "page 1 has 25 + cursor; page 2 has 5 + nil cursor", context do
        assert length(context.page1["candidates"]) == 25
        assert context.page1["next_cursor"] == "t3_p2cursor_6351"

        assert length(context.page2["candidates"]) == 5
        assert context.page2["next_cursor"] in [nil, ""]

        {:ok, context}
      end
    end
  end
end
