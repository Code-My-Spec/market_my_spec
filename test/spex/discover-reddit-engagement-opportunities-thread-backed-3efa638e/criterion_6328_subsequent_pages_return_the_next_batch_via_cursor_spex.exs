defmodule MarketMySpecSpex.Story705.Criterion6328Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6328 — Subsequent pages return the next batch via cursor.

  First call returns the first page + a `next_cursor`. Second call with
  that cursor returns the next batch (different threads) + nil cursor
  (end of listing).

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

  spex "subsequent pages return the next batch via cursor" do
    scenario "page 1 carries next_cursor; page 2 carries different titles + nil cursor" do
      given_ "a venue and a cassette with page-1 and page-2 interactions", context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        # RSS exposes no server cursor — the adapter derives next_cursor from
        # the last entry's fullname only when a FULL page (== limit, 25) comes
        # back. So page 1 must be a full page; its cursor is "t3_" <> last id.
        page1_children =
          for i <- 1..25 do
            %{title: "Page 1 — #{i}", id: "p1_#{i}", permalink: "/r/elixir/comments/p1_#{i}/"}
          end

        RedditHelpers.build_multi_cassette!("crit_6328_cursor", [
          [
            subreddit: "elixir",
            query: "elixir",
            after: nil,
            children: page1_children
          ],
          [
            subreddit: "elixir",
            query: "elixir",
            after: "t3_p1_25",
            children: [
              %{title: "Page 2 — A", id: "p2a", permalink: "/r/elixir/comments/p2a/"},
              %{title: "Page 2 — B", id: "p2b", permalink: "/r/elixir/comments/p2b/"}
            ]
          ]
        ])

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called for page 1 and again with its cursor", context do
        {page1, page2} =
          RedditHelpers.with_reddit_cassette("crit_6328_cursor", fn ->
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

      then_ "page 1 carries cursor; page 2 carries different titles + nil cursor", context do
        assert context.page1["next_cursor"] == "t3_p1_25",
               "expected page1.next_cursor='t3_p1_25', got: #{inspect(context.page1["next_cursor"])}"

        page1_titles = Enum.map(context.page1["candidates"], & &1["title"])
        page2_titles = Enum.map(context.page2["candidates"], & &1["title"])

        assert MapSet.disjoint?(MapSet.new(page1_titles), MapSet.new(page2_titles)),
               "expected disjoint titles across pages, got: #{inspect(page1_titles)} vs #{inspect(page2_titles)}"

        assert context.page2["next_cursor"] in [nil, ""],
               "expected page2 to end the listing (next_cursor nil)"

        {:ok, context}
      end
    end
  end
end
