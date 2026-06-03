defmodule MarketMySpecSpex.Story739.Criterion6528Spex do
  @moduledoc """
  Story 739 — Run a problem-discovery pipeline whose board is killable in one click
  Criterion 6528 — All four canonical verdicts (KEEP-PRODUCTIZABLE, KEEP-SERVICE-ONLY,
  WATCH, KILL) render on the Board LiveView.

  The Frame detail LiveView (the "killable in one click" surface) must
  render rows for all four canonical verdict types, not just KEEP/WATCH/KILL.
  Each verdict type must be visually distinguishable to the founder.

  Interaction surface: LiveView (founder opens the Frame detail page and
  sees the Board table).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.ListCandidates
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RedTeamCandidate
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunCluster
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunScore
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.ProblemDiscoveryHelpers

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

  spex "Frame Board LiveView renders all four canonical verdict types" do
    scenario "Authenticated founder views Frame detail and sees rows for KEEP-PRODUCTIZABLE, KEEP-SERVICE-ONLY, WATCH, and KILL" do
      given_ "a Frame whose pipeline run produced at least one Candidate in each of the four verdict tiers",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6528_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Mixed-verdict pipeline",
                  saved_searches: ["upwork|vendor onboarding"],
                  total_spent_min: 1,
                  hire_rate_min: 1,
                  min_money_gated_candidates: 1
                },
                agent_frame
              )

            frame_id =
              decode_payload(create_resp)["frame_id"] || decode_payload(create_resp)["id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunScore.execute(%{frame_id: frame_id}, agent_frame)

            {:reply, list_resp, _} =
              ListCandidates.execute(%{frame_id: frame_id}, agent_frame)

            survivors =
              decode_payload(list_resp)["candidates"]
              |> Enum.filter(fn c -> (c["score"] || 0) > 0 end)

            verdicts = ~w(keep_productizable keep_service_only watch kill)

            for {candidate, i} <- Enum.with_index(survivors) do
              {:reply, _, _} =
                RedTeamCandidate.execute(
                  %{
                    candidate_id: candidate["id"],
                    verdict: Enum.at(verdicts, rem(i, length(verdicts))),
                    kill_argument: "Prosecution argument #{i}.",
                    cheapest_kill_test: "Cheapest test #{i}."
                  },
                  agent_frame
                )
            end

            %{frame_id: frame_id}
          end)

        {token, _} = Fixtures.generate_user_magic_link_token(scope.user)

        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, Map.merge(context, Map.put(result, :authed_conn, authed_conn))}
      end

      when_ "the founder opens the Frame detail LiveView with the inline Board", context do
        {:ok, view, html} =
          live(context.authed_conn, "/app/problem-discovery/frames/#{context.frame_id}")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the Board renders a row for each of the four canonical verdicts", context do
        assert has_element?(context.view, "[data-test='board-row'][data-verdict='keep_productizable']"),
               "expected a row rendered with data-verdict='keep_productizable'"

        assert has_element?(context.view, "[data-test='board-row'][data-verdict='keep_service_only']"),
               "expected a row rendered with data-verdict='keep_service_only'"

        assert has_element?(context.view, "[data-test='board-row'][data-verdict='watch']"),
               "expected a row rendered with data-verdict='watch'"

        assert has_element?(context.view, "[data-test='board-row'][data-verdict='kill']"),
               "expected a row rendered with data-verdict='kill'"

        {:ok, context}
      end
    end
  end
end
