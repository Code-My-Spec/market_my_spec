defmodule MarketMySpecSpex.Story705.Criterion6350Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6350 — Engagement summary reflects Touchpoint history;
  latest by inserted_at; zeroed when none exist.

  When the Thread has Touchpoints, the candidate's `engagement` summary
  carries count = N, latest_state from the most-recently-inserted
  Touchpoint, plus that Touchpoint's angle and posted_at. When zero
  Touchpoints exist, all fields are nil/zero.

  Depends on story 716 schema (Touchpoint.state, Touchpoint.angle).
  Will fail until 716 lands.

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

  spex "engagement summary reflects Touchpoint history; latest by inserted_at" do
    scenario "one Thread with a posted Touchpoint surfaces in scan with engagement count=1, latest_state=:posted" do
      given_ "Sam's account has an enabled r/elixir venue, a pre-existing Thread T-engaged with a posted Touchpoint, and a fresh Thread cassette",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        engaged_thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "eng_t3_abc",
            url: "https://www.reddit.com/r/elixir/comments/eng_t3_abc/_/",
            title: "Engaged thread"
          })

        Fixtures.touchpoint_fixture(scope, engaged_thread, %{
          state: :posted,
          angle: "intro harness eng as the missing piece",
          polished_body: "Long-form polished body",
          link_target: "https://marketmyspec.com/example",
          comment_url: "https://www.reddit.com/r/elixir/comments/eng_t3_abc/_/xyz",
          posted_at: DateTime.utc_now() |> DateTime.add(-7 * 24 * 3600)
        })

        RedditHelpers.build_search_cassette!("crit_6350_engagement",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{
              title: "Engaged thread",
              score: 5,
              num_comments: 1,
              id: "eng_t3_abc",
              permalink: "/r/elixir/comments/eng_t3_abc/_/"
            },
            %{
              title: "Fresh thread",
              score: 2,
              num_comments: 0,
              id: "fresh_t3_def",
              permalink: "/r/elixir/comments/fresh_t3_def/_/"
            }
          ]
        )

        {:ok,
         Map.merge(context, %{
           frame: build_frame(scope),
           engaged_source_thread_id: "eng_t3_abc"
         })}
      end

      when_ "the agent runs the search", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6350_engagement", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the engaged Thread's candidate carries engagement count=1 and latest_state=:posted; the fresh one carries count=0",
            context do
        candidates = context.payload["candidates"]

        engaged =
          Enum.find(candidates, fn c ->
            c["url"] =~ context.engaged_source_thread_id
          end)

        fresh =
          Enum.find(candidates, fn c ->
            c["url"] =~ "fresh_t3_def"
          end)

        assert engaged, "expected engaged-thread candidate in response"
        assert fresh, "expected fresh-thread candidate in response"

        assert engaged["engagement"]["count"] == 1,
               "expected engaged.engagement.count=1, got: #{inspect(engaged["engagement"])}"

        assert engaged["engagement"]["latest_state"] in ["posted", :posted],
               "expected engaged.latest_state=:posted, got: #{inspect(engaged["engagement"]["latest_state"])}"

        assert engaged["engagement"]["latest_angle"] == "intro harness eng as the missing piece",
               "expected angle preserved, got: #{inspect(engaged["engagement"]["latest_angle"])}"

        assert engaged["engagement"]["latest_posted_at"] != nil,
               "expected posted_at populated for posted touchpoint"

        assert fresh["engagement"]["count"] == 0
        assert fresh["engagement"]["latest_state"] in [nil]
        assert fresh["engagement"]["latest_angle"] in [nil]
        assert fresh["engagement"]["latest_posted_at"] in [nil]

        {:ok, context}
      end
    end
  end
end
