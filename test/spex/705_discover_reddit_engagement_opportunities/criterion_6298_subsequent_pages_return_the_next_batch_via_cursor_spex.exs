defmodule MarketMySpecSpex.Story705.Criterion6298Spex do
  @moduledoc """
  Story 705 — Criterion 6298 — Subsequent pages return the next batch via cursor.

  First call: no cursor → cassette returns 2 threads + `after = "t3_p2cursor"`.
  Response envelope carries `next_cursor: "t3_p2cursor"`.

  Second call: `cursor: "t3_p2cursor"` → cassette returns 2 different threads
  with `after = nil` (end of listing). Response carries `next_cursor: nil`.

  Implementation note: requires Engagements.Search to thread a `:cursor`
  opt through to the adapter and the orchestrator to expose `next_cursor`
  in its envelope. SearchEngagements MCP tool schema needs an optional
  `cursor` arg. Spex will FAIL until that plumbing lands.
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

  spex "subsequent pages return the next batch via cursor" do
    scenario "first call returns next_cursor; second call with that cursor returns page 2" do
      given_ "a venue and a cassette with page-1 and page-2 interactions",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        RedditHelpers.build_multi_cassette!("crit_6298_cursor", [
          [
            subreddit: "elixir",
            query: "elixir",
            after: nil,
            after_cursor: "t3_p2cursor",
            children: [
              %{title: "Page 1 — A", score: 1, num_comments: 0, id: "p1a",
                permalink: "/r/elixir/comments/p1a/"},
              %{title: "Page 1 — B", score: 1, num_comments: 0, id: "p1b",
                permalink: "/r/elixir/comments/p1b/"}
            ]
          ],
          [
            subreddit: "elixir",
            query: "elixir",
            after: "t3_p2cursor",
            after_cursor: nil,
            children: [
              %{title: "Page 2 — A", score: 1, num_comments: 0, id: "p2a",
                permalink: "/r/elixir/comments/p2a/"},
              %{title: "Page 2 — B", score: 1, num_comments: 0, id: "p2b",
                permalink: "/r/elixir/comments/p2b/"}
            ]
          ]
        ])

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called for page 1, then page 2 with the cursor", context do
        {first, second} =
          RedditHelpers.with_reddit_cassette("crit_6298_cursor", fn ->
            {:reply, r1, _f1} = SearchEngagements.execute(%{query: "elixir"}, context.frame)
            page1 = decode(r1)

            {:reply, r2, _f2} =
              SearchEngagements.execute(
                %{query: "elixir", cursor: page1["next_cursor"]},
                context.frame
              )

            {page1, decode(r2)}
          end)

        {:ok, Map.merge(context, %{page1: first, page2: second})}
      end

      then_ "page 1 carries the cursor; page 2 carries different titles + no cursor", context do
        assert context.page1["next_cursor"] == "t3_p2cursor",
               "expected page1.next_cursor='t3_p2cursor', got: #{inspect(context.page1["next_cursor"])}"

        page1_titles = Enum.map(context.page1["candidates"], & &1["title"])
        page2_titles = Enum.map(context.page2["candidates"], & &1["title"])

        assert page1_titles == ["Page 1 — A", "Page 1 — B"] or
                 page1_titles == ["Page 1 — B", "Page 1 — A"]

        assert page2_titles == ["Page 2 — A", "Page 2 — B"] or
                 page2_titles == ["Page 2 — B", "Page 2 — A"],
               "expected page2 titles, got: #{inspect(page2_titles)}"

        assert MapSet.disjoint?(MapSet.new(page1_titles), MapSet.new(page2_titles))

        assert context.page2["next_cursor"] in [nil, ""],
               "expected page2 to end the listing (next_cursor nil or empty)"

        {:ok, context}
      end
    end
  end
end
