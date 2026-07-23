defmodule MarketMySpecSpex.Story705.Criterion6324Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6324 — Disabled venues are not queried.

  Account has one enabled and one disabled Reddit venue. Cassette only
  includes the enabled venue's interaction. The orchestrator must skip
  the disabled venue entirely — no HTTP call, no surfaced candidate, no
  failure entry.

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

  spex "disabled venues are skipped entirely (no HTTP call, no candidate, no failure)" do
    scenario "the orchestrator queries only the enabled venue" do
      given_ "an enabled r/elixir and a DISABLED r/programming; cassette has only r/elixir",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "programming", enabled: false})

        RedditHelpers.build_search_cassette!("crit_6324_disabled",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "Enabled-only", score: 2, num_comments: 0, id: "en1",
              permalink: "/r/elixir/comments/en1/_/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6324_disabled", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "only the enabled venue's candidate appears AND no failures", context do
        candidates = context.payload["candidates"]
        failures = context.payload["failures"]

        assert length(candidates) == 1
        [c] = candidates
        assert c["url"] =~ "/r/elixir/"

        assert failures == [],
               "expected no failures when only enabled venues run, got: #{inspect(failures)}"

        {:ok, context}
      end
    end
  end
end
