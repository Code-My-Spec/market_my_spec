defmodule MarketMySpecSpex.Story733.Criterion6499Spex do
  @moduledoc """
  Story 733 — 6499. Server-first RSS: a Reddit search no longer requires
  an online agent. When none is paired, the search runs directly against
  Reddit's public RSS feed and still returns candidates. (The agent
  transport now only acts as a fallback for direct-call failures, and is
  slated for removal — see the search orchestrator.)
  """
  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  defp decode_payload(%Response{content: parts}) when is_list(parts) do
    parts
    |> Enum.map_join("\n", fn
      %{"text" => t} -> t
      %{text: t} -> t
      other -> inspect(other)
    end)
    |> Jason.decode!()
  end

  spex "no online agent: Reddit search runs directly against the public RSS feed" do
    scenario "search with no paired agent returns candidates from the direct RSS path" do
      given_ "an authenticated user with a reddit venue, NO agent paired, and a direct-RSS cassette",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        RedditHelpers.build_search_cassette!("crit_6499_direct",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{
              title: "Direct RSS works without an agent",
              id: "noagent1",
              permalink: "/r/elixir/comments/noagent1/_/",
              selftext: "No paired agent — the server hit Reddit's RSS feed directly."
            }
          ]
        )

        frame = %{assigns: %{current_scope: scope}, context: %{session_id: "spec"}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "search_engagements is invoked", context do
        payload =
          RedditHelpers.with_reddit_cassette("crit_6499_direct", fn ->
            {:reply, response, _frame} =
              SearchEngagements.execute(%{query: "elixir"}, context.frame)

            decode_payload(response)
          end)

        {:ok, Map.put(context, :payload, payload)}
      end

      then_ "candidates come back from the direct path with no failures and no agent error",
            context do
        assert context.payload["candidates"] != [],
               "expected direct-RSS candidates with no agent, got none"

        assert context.payload["failures"] == [],
               "expected no failures from the direct path, got: #{inspect(context.payload["failures"])}"

        [c | _] = context.payload["candidates"]
        assert c["source"] == "reddit"
        assert is_binary(c["title"])

        {:ok, context}
      end
    end
  end
end
