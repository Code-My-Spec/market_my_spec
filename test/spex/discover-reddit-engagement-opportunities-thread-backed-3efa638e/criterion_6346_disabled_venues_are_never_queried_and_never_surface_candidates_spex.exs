defmodule MarketMySpecSpex.Story705.Criterion6346Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6346 — Disabled venues are never queried and never surface
  candidates.

  Sister criterion to 6324; pinned separately as a Three Amigos scenario
  for clarity. Asserts the orchestrator filter is at the query layer:
  cassette interaction count is 1 (enabled venue only), no candidate
  comes from the disabled venue, no failure entry references it.

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

  spex "disabled venues never queried, never surface, never fail" do
    scenario "enabled venue has cassette; disabled does not; no leakage either way" do
      given_ "two venues; r/elixir enabled, r/programming DISABLED",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "programming", enabled: false})

        RedditHelpers.build_search_cassette!("crit_6346_disabled",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "Enabled-only", score: 2, num_comments: 0, id: "ena1",
              permalink: "/r/elixir/comments/ena1/_/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6346_disabled", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "only enabled venue's candidate; failures empty", context do
        candidates = context.payload["candidates"]
        failures = context.payload["failures"]

        assert length(candidates) == 1
        [c] = candidates
        assert c["url"] =~ "/r/elixir/"
        refute c["url"] =~ "/r/programming/"

        assert failures == [],
               "expected no failures (disabled venue is filtered before fan-out, not failed at fan-out), got: #{inspect(failures)}"

        {:ok, context}
      end
    end
  end
end
