defmodule MarketMySpecSpex.Story743.Criterion6564Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6564 — Frame holds a description and three saved searches.

  Committing a Frame with a description and three saved-search entries
  must round-trip both: GetFrame returns the description text and the
  three saved searches (with their source + query intact).

  Interaction surface: MCP tool execution (CreateFrame + GetFrame).
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

  spex "Frame round-trips a description and exactly three saved searches" do
    scenario "Commit a Frame with description + 3 saved searches; GetFrame returns all 4 attributes intact" do
      given_ "an account-scoped agent frame", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.put(context, :agent_frame, build_frame(scope))}
      end

      when_ "the agent commits a Frame with description + 3 saved searches and reads it back",
            context do
        searches = [
          %{source: "upwork", query: "vendor onboarding migration"},
          %{source: "upwork", query: "supplier portal consolidation"},
          %{source: "upwork", query: "agency sub-account intake"}
        ]

        description = "Hypothesis: agencies struggle with sub-account consolidation post-acquisition."

        {:reply, create_resp, _} =
          CreateFrame.execute(
            %{
              description: description,
              saved_searches: searches,
              money_gate: %{total_spent_min: 5_000, hire_rate_min: 50},
              kill_condition: %{min_money_gated_candidates: 3}
            },
            context.agent_frame
          )

        frame_id = decode_payload(create_resp)["frame_id"]

        {:reply, get_resp, _} =
          GetFrame.execute(%{frame_id: frame_id}, context.agent_frame)

        {:ok,
         Map.merge(context, %{
           expected_description: description,
           expected_searches: searches,
           persisted: decode_payload(get_resp)
         })}
      end

      then_ "the persisted Frame's description matches", context do
        assert context.persisted["description"] == context.expected_description
        {:ok, context}
      end

      then_ "the persisted Frame carries exactly the 3 saved searches (source + query intact)",
            context do
        returned = context.persisted["saved_searches"] || []

        assert length(returned) == 3,
               "expected exactly 3 saved searches; got #{length(returned)}"

        normalized =
          Enum.map(returned, fn ss ->
            %{source: ss["source"] || ss[:source], query: ss["query"] || ss[:query]}
          end)

        assert normalized == context.expected_searches
        {:ok, context}
      end
    end
  end
end
