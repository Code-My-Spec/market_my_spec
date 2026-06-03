defmodule MarketMySpecSpex.Story742.Criterion6557Spex do
  @moduledoc """
  Story 742 — Set the money-gate threshold at Frame time
  Criterion 6557 — Frame records a kill_condition the founder commits to.

  The Frame compose form requires the founder to specify a
  min_money_gated_candidates threshold. That value must persist on the
  Frame's kill_condition field — it's the falsifiable pre-commitment
  per Blank/Fitzpatrick.

  Interaction surface: LiveView form submission; verify via GetFrame.
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

  spex "Frame records the founder's kill_condition pre-commitment" do
    scenario "Committing a Frame with min_money_gated_candidates=4 persists that value on kill_condition" do
      given_ "the founder is on the new-Frame compose page", context do
        scope = Fixtures.account_scoped_user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(scope.user)
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, view, _} = live(authed_conn, "/app/problem-discovery/frames/new")

        {:ok,
         Map.merge(context, %{
           agent_frame: build_frame(scope),
           view: view
         })}
      end

      when_ "the founder submits with min_money_gated_candidates=4", context do
        context.view
        |> form("[data-test='frame-form']",
          frame: %{
            description: "kill_condition pre-commitment",
            saved_searches_text: "upwork: vendor onboarding\nupwork: supplier consolidation\nupwork: intake automation",
            total_spent_min: "5000",
            hire_rate_min: "50",
            min_money_gated_candidates: "4"
          }
        )
        |> render_submit()

        {:reply, list_resp, _} = ListFrames.execute(%{}, context.agent_frame)
        [created | _] = decode_payload(list_resp)["frames"] || []

        {:reply, get_resp, _} =
          GetFrame.execute(%{frame_id: created["id"]}, context.agent_frame)

        {:ok, Map.put(context, :persisted, decode_payload(get_resp))}
      end

      then_ "the Frame's kill_condition carries min_money_gated_candidates=4", context do
        kc = context.persisted["kill_condition"] || %{}

        value = kc["min_money_gated_candidates"] || kc[:min_money_gated_candidates]

        assert value == 4,
               "expected kill_condition.min_money_gated_candidates=4; got: #{inspect(value)} (full kc: #{inspect(kc)})"
        {:ok, context}
      end
    end
  end
end
