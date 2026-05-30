defmodule MarketMySpecSpex.Story733.Criterion6499Spex do
  @moduledoc """
  Story 733 — 6499. When the user has no online agent, a Reddit
  operation surfaces a user-facing error message that links to
  /agents.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  spex "no online agent surfaces user-facing error with link to /agents" do
    scenario "search invoked while the user has no paired+online agent" do
      given_ "an authenticated user with a reddit venue and NO agent paired", context do
        scope = Fixtures.account_scoped_user_fixture()
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})
        frame = %{assigns: %{current_scope: scope}, context: %{session_id: "spec"}}

        RedditHelpers.build_search_cassette!("crit_6499_no_agent",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{
              title: "Elixir tip",
              score: 5,
              num_comments: 1,
              id: "c1",
              permalink: "/r/elixir/comments/c1/elixir_tip/"
            }
          ]
        )

        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "search_engagements is invoked", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6499_no_agent", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response text references /agents", context do
        text =
          context.response.content
          |> List.wrap()
          |> Enum.map_join("\n", fn
            %{"text" => t} -> t
            %{text: t} -> t
            other -> inspect(other)
          end)

        assert text =~ "/agents",
               "expected the no-online-agent error to reference /agents; got: #{text}"

        {:ok, context}
      end
    end
  end
end
