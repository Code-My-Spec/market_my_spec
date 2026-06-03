defmodule MarketMySpecSpex.Story739.Criterion6536Spex do
  @moduledoc """
  Story 739 — Run a problem-discovery pipeline whose board is killable in one click
  Criterion 6536 — Empty Gather halts the pipeline and notifies the founder.

  If Gather returns zero JobPostings across all saved searches, the
  pipeline halts cleanly with that empty artifact persisted (per rule
  c4b557ec — "A stage that emits zero records halts the pipeline cleanly
  with that empty artifact persisted; no downstream stage runs against
  an empty input"). The founder is notified through the visible surface.

  Interaction surface: MCP tool execution + LiveView observation. Downstream
  stages (RunCluster, RunScore) refuse to run, and the Frame detail
  LiveView surfaces an "empty Gather" notification.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunCluster
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather
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

  spex "Empty Gather halts the pipeline cleanly and notifies the founder" do
    scenario "Gather returns zero postings; subsequent Cluster refuses to run and LiveView surfaces the empty-Gather notification" do
      given_ "a Frame whose saved searches are constructed to return zero results",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        {:reply, create_resp, _} =
          CreateFrame.execute(
            %{
              description: "Empty-Gather edge case",
              saved_searches: [
                %{source: "upwork", query: "definitively_unmatched_query_string_xyzzy_42"},
                %{source: "upwork", query: "another_unmatched_string_quux_99"},
                %{source: "upwork", query: "third_unmatched_qwerty_xx"}
              ],
              money_gate: %{total_spent_min: 5_000, hire_rate_min: 50},
              kill_condition: %{min_money_gated_candidates: 3}
            },
            agent_frame
          )

        frame_id = decode_payload(create_resp)["frame_id"] || decode_payload(create_resp)["id"]

        {token, _} = Fixtures.generate_user_magic_link_token(scope.user)

        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok,
         Map.merge(context, %{
           agent_frame: agent_frame,
           frame_id: frame_id,
           authed_conn: authed_conn
         })}
      end

      when_ "the agent runs Gather (which returns zero postings) and then attempts to run Cluster",
            context do
        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6536_when", fn ->
            {:reply, gather_resp, _} =
              RunGather.execute(%{frame_id: context.frame_id}, context.agent_frame)

            gather_payload = decode_payload(gather_resp)

            cluster_result =
              try do
                {:reply, resp, _} =
                  RunCluster.execute(%{frame_id: context.frame_id}, context.agent_frame)

                {:ok, decode_payload(resp)}
              rescue
                e -> {:error, e}
              catch
                kind, value -> {kind, value}
              end

            %{gather_payload: gather_payload, cluster_result: cluster_result}
          end)

        {:ok, Map.merge(context, result)}
      end

      then_ "Gather reports zero postings persisted across all saved searches", context do
        per_search = context.gather_payload["per_saved_search"] || []

        for entry <- per_search do
          gathered = entry["gathered"] || entry[:gathered]

          assert gathered == 0,
                 "expected every saved search to return zero postings; got entry: #{inspect(entry)}"
        end

        {:ok, context}
      end

      then_ "Cluster refuses to run against the empty Gather and surfaces a halt status",
            context do
        case context.cluster_result do
          {:ok, payload} ->
            status = payload["status"] || payload[:status]

            assert status in ["halted", "empty_upstream", "no_input"],
                   "expected Cluster response to indicate a pipeline halt; got: #{inspect(payload)}"

          {:error, _} ->
            {:ok, context}

          {kind, value} ->
            flunk("unexpected Cluster outcome: #{kind} #{inspect(value)}")
        end

        {:ok, context}
      end

      then_ "the Frame detail LiveView surfaces an empty-Gather notification to the founder",
            context do
        {:ok, view, _html} =
          live(context.authed_conn, "/problem-discovery/frames/#{context.frame_id}")

        assert has_element?(view, "[data-test='empty-gather-notice']"),
               "expected the Frame detail page to surface a [data-test='empty-gather-notice'] element"

        {:ok, context}
      end
    end
  end
end
