defmodule MarketMySpecSpex.Story716.Criterion6342Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6342 — Engagement summary fields on story 705's search
  candidates are populated from touchpoints with explicit state (no
  longer inferred from posted_at).

  Cross-story integration: stage a Touchpoint, transition to :abandoned.
  Even though `posted_at` may be nil (or set, depending on prior path),
  the engagement summary's `latest_state` reads from the state COLUMN —
  so it should report :abandoned. Tests the contract that consumers
  trust the column over inference.

  Interaction surface: MCP tool execution (agent surface — both
  StageResponse + UpdateTouchpoint + SearchEngagements).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpec.McpServers.Engagements.Tools.StageResponse
  alias MarketMySpec.McpServers.Engagements.Tools.UpdateTouchpoint
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

  spex "engagement summary reads from the state column (not inferred from posted_at)" do
    scenario "Touchpoint state moves through :posted → :abandoned; summary reports :abandoned" do
      given_ "Sam's account with an enabled r/elixir venue, a pre-seeded Thread with a posted-then-abandoned Touchpoint",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "elixir", enabled: true
        })

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "engsum001",
            url: "https://www.reddit.com/r/elixir/comments/engsum001/_/",
            title: "Engagement-summary probe"
          })

        frame = build_frame(scope)

        # Create touchpoint via stage_response (defaults to :staged)
        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              polished_body: "Original body",
              link_target: "https://marketmyspec.com/x",
              angle: "Initial angle"
            },
            frame
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        # Transition to :posted (so posted_at + comment_url are set)
        {:reply, _, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: touchpoint_id,
              state: "posted",
              comment_url: "https://www.reddit.com/r/elixir/comments/engsum001/_/posted",
              posted_at: DateTime.utc_now() |> DateTime.to_iso8601()
            },
            frame
          )

        # Now transition to :abandoned (posted_at stays per R5; state changes to :abandoned)
        {:reply, _, _} =
          UpdateTouchpoint.execute(
            %{touchpoint_id: touchpoint_id, state: "abandoned"},
            frame
          )

        # Cassette so the search call is hermetic
        RedditHelpers.build_search_cassette!("crit_6342_engsum",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "Engagement-summary probe", score: 5, num_comments: 1,
              id: "engsum001", permalink: "/r/elixir/comments/engsum001/_/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: frame, thread: thread})}
      end

      when_ "the agent runs search_engagements (story 705 surface)", context do
        {:reply, response, _} =
          RedditHelpers.with_reddit_cassette("crit_6342_engsum", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the candidate's engagement.latest_state is :abandoned (reads from the state column, NOT inferred from posted_at)",
            context do
        candidates = context.payload["candidates"]

        refute Enum.empty?(candidates), "expected the surfaced candidate"

        engsum_candidate =
          Enum.find(candidates, &(&1["url"] =~ "engsum001"))

        assert engsum_candidate, "expected the engsum001 candidate"

        engagement = engsum_candidate["engagement"]
        assert engagement, "expected engagement summary present"

        latest_state = engagement["latest_state"]

        assert latest_state in ["abandoned", :abandoned],
               "expected latest_state :abandoned (reading from state column), got: #{inspect(latest_state)} — implementation may be inferring state from posted_at instead"

        # count should still be 1 (the touchpoint exists)
        assert engagement["count"] == 1,
               "expected count=1, got: #{inspect(engagement["count"])}"

        {:ok, context}
      end
    end
  end
end
