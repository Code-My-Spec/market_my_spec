defmodule MarketMySpecSpex.Story742.Criterion6556Spex do
  @moduledoc """
  Story 742 — Set the money-gate threshold at Frame time
  Criterion 6556 — Founder's threshold values land on the Frame verbatim.

  When the founder submits the Frame compose form with total_spent_min
  and hire_rate_min values, those exact values must persist on the
  Frame artifact — no model-generated default substituted, no rounding,
  no transformation.

  Interaction surface: LiveView (Frames index/new — the founder-direct
  Frame compose form per story 742). The committed Frame is observable
  via GetFrame MCP tool.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.GetFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.ListFrames
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

  spex "Founder's threshold values land on the Frame verbatim" do
    scenario "Submitting the Frame compose form with total_spent_min=$7,500 and hire_rate_min=65% persists those exact values" do
      given_ "the founder is authenticated and on the new-Frame compose page",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(scope.user)
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, view, _} = live(authed_conn, "/problem-discovery/frames/new")

        {:ok,
         Map.merge(context, %{
           scope: scope,
           authed_conn: authed_conn,
           view: view,
           agent_frame: build_frame(scope)
         })}
      end

      when_ "the founder fills the form with total_spent_min=7500, hire_rate_min=65, and submits",
            context do
        context.view
        |> form("[data-test='frame-form']",
          frame: %{
            description: "Hypothesis — vendor onboarding pain among acquired agencies",
            saved_searches_text: "upwork: vendor onboarding\nupwork: supplier consolidation\nupwork: intake automation",
            total_spent_min: "7500",
            hire_rate_min: "65",
            min_money_gated_candidates: "3"
          }
        )
        |> render_submit()

        {:reply, list_resp, _} = ListFrames.execute(%{}, context.agent_frame)
        [created | _] = decode_payload(list_resp)["frames"] || []

        {:reply, get_resp, _} =
          GetFrame.execute(%{frame_id: created["id"]}, context.agent_frame)

        {:ok, Map.put(context, :persisted, decode_payload(get_resp))}
      end

      then_ "the persisted Frame carries total_spent_min=7500 and hire_rate_min=65 verbatim",
            context do
        gate = context.persisted["money_gate"] || %{}

        total_spent =
          gate["total_spent_min"] ||
            (gate["total_spent_min"] && String.to_integer(gate["total_spent_min"])) ||
            gate[:total_spent_min]

        hire_rate =
          gate["hire_rate_min"] ||
            (gate["hire_rate_min"] && String.to_integer(gate["hire_rate_min"])) ||
            gate[:hire_rate_min]

        assert total_spent == 7500,
               "expected total_spent_min=7500; got: #{inspect(total_spent)} (full gate: #{inspect(gate)})"

        assert hire_rate == 65,
               "expected hire_rate_min=65; got: #{inspect(hire_rate)} (full gate: #{inspect(gate)})"
        {:ok, context}
      end
    end
  end
end
