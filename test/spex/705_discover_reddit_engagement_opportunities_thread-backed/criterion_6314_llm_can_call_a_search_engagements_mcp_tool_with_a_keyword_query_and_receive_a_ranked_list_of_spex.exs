defmodule MarketMySpecSpex.Story705.Criterion6314Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6314 — LLM can call a `search_engagements` MCP tool with a
  keyword query and receive a ranked list of candidate threads.

  Top-level "tool wire works" assertion. Agent calls the MCP tool with a
  query and an enabled Reddit venue; cassette serves three Reddit posts;
  response carries a non-empty candidates list. Per-candidate shape is
  pinned by criterion 6315; ranking ordering by 6326/6327.

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

  spex "LLM calls search_engagements and receives a ranked candidate list" do
    scenario "agent passes a keyword query and gets a non-empty list back" do
      given_ "an account with one enabled r/elixir venue and a cassette with 3 threads",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit,
          identifier: "elixir",
          enabled: true
        })

        RedditHelpers.build_search_cassette!("crit_6314_call",
          subreddit: "elixir",
          query: "testing",
          children: [
            %{
              title: "ExUnit tip",
              score: 10,
              num_comments: 2,
              id: "c1",
              permalink: "/r/elixir/comments/c1/exunit_tip/"
            },
            %{
              title: "Mox vs Bypass",
              score: 7,
              num_comments: 4,
              id: "c2",
              permalink: "/r/elixir/comments/c2/mox_vs_bypass/"
            },
            %{
              title: "Property testing",
              score: 3,
              num_comments: 1,
              id: "c3",
              permalink: "/r/elixir/comments/c3/property_testing/"
            }
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "the LLM calls search_engagements with query 'testing'", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6314_call", fn ->
            SearchEngagements.execute(%{query: "testing"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the payload includes a candidates list with all 3 threads", context do
        candidates = context.payload["candidates"]
        assert is_list(candidates)
        assert length(candidates) == 3, "expected 3 candidates, got #{length(candidates)}"

        for c <- candidates do
          assert is_map(c)
          assert is_binary(c["title"])
        end

        {:ok, context}
      end
    end
  end
end
