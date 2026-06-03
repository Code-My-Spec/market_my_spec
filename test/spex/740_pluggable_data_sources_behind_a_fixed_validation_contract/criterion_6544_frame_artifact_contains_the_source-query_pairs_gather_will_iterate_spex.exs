defmodule MarketMySpecSpex.Story740.Criterion6544Spex do
  @moduledoc """
  Story 740 — Pluggable data sources behind a fixed validation contract
  Criterion 6544 — Frame artifact contains the source-query pairs Gather
  will iterate.

  The Frame's `saved_searches` field is the canonical list of
  (source, query) pairs the Gather stage consumes. Per Three Amigos
  rule 5c4269fe, the format mirrors SavedSearch's source-wildcard +
  query pattern. The committed Frame artifact must surface these pairs
  verbatim (no transformation, no dropping).

  Interaction surface: MCP tool execution (CreateFrame + GetFrame) to
  verify the saved_searches round-trip.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.GetFrame
  alias MarketMySpecSpex.Fixtures

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

  spex "Frame artifact carries its committed (source, query) pairs verbatim" do
    scenario "Committing a Frame with three saved searches surfaces those exact three pairs on GetFrame" do
      given_ "the founder is composing a Frame with three saved searches", context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        saved_searches = [
          "upwork|vendor onboarding migration",
          "upwork|GoHighLevel sub-account consolidation",
          "upwork|supplier intake automation"
        ]

        {:ok,
         Map.merge(context, %{
           agent_frame: agent_frame,
           saved_searches: saved_searches
         })}
      end

      when_ "the agent commits the Frame and reads it back via GetFrame", context do
        {:reply, create_resp, _} =
          CreateFrame.execute(
            %{
              description: "Source-query pair round-trip",
              saved_searches: context.saved_searches,
              total_spent_min: 5_000,
              hire_rate_min: 50,
              min_money_gated_candidates: 3
            },
            context.agent_frame
          )

        frame_id = decode_payload(create_resp)["frame_id"]

        {:reply, get_resp, _} =
          GetFrame.execute(%{frame_id: frame_id}, context.agent_frame)

        {:ok, Map.put(context, :get_payload, decode_payload(get_resp))}
      end

      then_ "the returned Frame carries exactly the committed (source, query) pairs",
            context do
        returned = context.get_payload["saved_searches"] || []

        normalized =
          Enum.map(returned, fn ss ->
            %{
              source: ss["source"] || ss[:source],
              query: ss["query"] || ss[:query]
            }
          end)

        assert normalized == context.saved_searches,
               "expected GetFrame to return the committed saved_searches verbatim; got: #{inspect(normalized)}"
        {:ok, context}
      end
    end
  end
end
