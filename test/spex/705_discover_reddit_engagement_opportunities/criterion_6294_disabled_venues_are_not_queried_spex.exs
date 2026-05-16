defmodule MarketMySpecSpex.Story705.Criterion6294Spex do
  @moduledoc """
  Story 705 — Criterion 6294 — Disabled venues are not queried.

  Two Reddit venues: r/elixir (enabled), r/programming (DISABLED). Cassette
  only has the r/elixir interaction. If the orchestrator queried the
  disabled venue, ReqCassette would raise on the unmatched URL.
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

  spex "disabled venues are not queried" do
    scenario "the disabled venue's URL is absent from the candidate list AND from HTTP traffic" do
      given_ "an enabled r/elixir venue and a DISABLED r/programming venue; cassette has r/elixir only",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "programming", enabled: false})

        RedditHelpers.build_search_cassette!("crit_6294_disabled",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "Enabled venue thread", score: 2, num_comments: 0, id: "en1",
              permalink: "/r/elixir/comments/en1/enabled/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6294_disabled", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode(response))}
      end

      then_ "only the enabled venue's candidate appears AND no failures reported", context do
        candidates = context.payload["candidates"]
        failures = context.payload["failures"]

        assert length(candidates) == 1
        [c] = candidates
        assert c["url"] =~ "/r/elixir/"

        # A disabled venue should not show up as a "failure" either — the
        # orchestrator skips it before fan-out, not as a failed call.
        assert failures == [],
               "expected no failures when only enabled venues run, got: #{inspect(failures)}"

        {:ok, context}
      end
    end
  end
end
