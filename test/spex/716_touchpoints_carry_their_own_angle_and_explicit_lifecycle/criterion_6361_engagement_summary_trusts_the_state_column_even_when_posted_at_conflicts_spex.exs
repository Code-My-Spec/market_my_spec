defmodule MarketMySpecSpex.Story716.Criterion6361Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6361 — Engagement summary trusts the state column even
  when posted_at conflicts.

  Sister to 6342; pinned via Three Amigos scenario. Engagement summary
  is derived from the explicit `state` column on the latest Touchpoint
  — never inferred from posted_at, comment_url, or any other field.
  Order: stage → post → abandon. After abandon, summary shows
  latest_state = :abandoned even though posted_at is set (the
  conflicting signal). State column wins.

  Interaction surface: MCP tool execution (cross-tool: SearchEngagements
  + Touchpoint lifecycle tools).
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

  defp find_candidate(payload, thread_id) do
    candidates = payload["candidates"] || payload["search_candidates"] || []
    Enum.find(candidates, &((&1["thread_id"] || &1[:thread_id]) == thread_id))
  end

  spex "engagement summary uses explicit state, not posted_at inference" do
    scenario "Touchpoint progresses stage → post → abandon; summary derives latest_state from state column" do
      given_ "a thread persisted from a prior search; a touchpoint going stage → posted → abandoned",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "ess361"})

        # Orchestrator only searches enabled venues; without this venue the
        # cassette is never consulted and the thread never surfaces.
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        frame = build_frame(scope)

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              polished_body: "Body for explicit-state test",
              link_target: "https://x",
              angle: "explicit state path"
            },
            frame
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        posted_at = DateTime.utc_now() |> DateTime.truncate(:second)

        {:reply, _, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: touchpoint_id,
              state: "posted",
              comment_url: "https://www.reddit.com/r/elixir/comments/ess361/_/xyz",
              posted_at: DateTime.to_iso8601(posted_at)
            },
            frame
          )

        {:reply, _, _} =
          UpdateTouchpoint.execute(
            %{touchpoint_id: touchpoint_id, state: "abandoned"},
            frame
          )

        {:ok,
         Map.merge(context, %{
           frame: frame,
           thread: thread,
           touchpoint_id: touchpoint_id,
           posted_at: posted_at
         })}
      end

      when_ "search_engagements returns the thread among candidates", context do
        RedditHelpers.build_search_cassette!("story_716_criterion_6361",
          subreddit: "elixir",
          query: "harness",
          children: [
            %{
              id: "ess361",
              subreddit: "elixir",
              title: "Same thread surfaced again",
              author: "alice",
              created_utc: 1_711_500_000.0,
              num_comments: 12,
              score: 8,
              permalink: "/r/elixir/comments/ess361/_/",
              url: "https://reddit.com/r/elixir/comments/ess361/_",
              selftext: "body"
            }
          ]
        )

        {:reply, search_resp, _} =
          RedditHelpers.with_reddit_cassette("story_716_criterion_6361", fn ->
            SearchEngagements.execute(%{query: "harness"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(search_resp))}
      end

      then_ "engagement summary on the candidate has latest_state :abandoned (not inferred from posted_at)",
            context do
        candidate = find_candidate(context.payload, context.thread.id)
        assert candidate, "expected the stage→post→abandon thread among candidates"

        summary = candidate["engagement"] || candidate[:engagement] || %{}

        latest_state = summary["latest_state"] || summary[:latest_state]

        assert latest_state in ["abandoned", :abandoned],
               "expected latest_state :abandoned (explicit column), got: #{inspect(latest_state)}"

        latest_angle = summary["latest_angle"] || summary[:latest_angle]
        assert latest_angle == "explicit state path"

        latest_posted_at = summary["latest_posted_at"] || summary[:latest_posted_at]

        assert latest_posted_at != nil,
               "expected latest_posted_at still surfaced (was set during :posted leg)"

        {:ok, context}
      end
    end
  end
end
