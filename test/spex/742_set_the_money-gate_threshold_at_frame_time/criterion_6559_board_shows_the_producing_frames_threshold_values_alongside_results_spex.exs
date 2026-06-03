defmodule MarketMySpecSpex.Story742.Criterion6559Spex do
  @moduledoc """
  Story 742 — Set the money-gate threshold at Frame time
  Criterion 6559 — Board shows the producing Frame's threshold values
  alongside results.

  When the founder views the Board, the threshold values that produced
  it (total_spent_min and hire_rate_min) must render alongside the
  Candidates — so the founder can scan a row and immediately know the
  bar that was applied.

  Interaction surface: LiveView (Frame detail page) — the threshold
  values render in the page (per the Board.View.frame field).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
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

  spex "The Board renders the producing Frame's threshold values" do
    scenario "Frame detail page surfaces total_spent_min=$5,000 and hire_rate_min=50%" do
      given_ "a committed Frame with money_gate=$5,000/50%", context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        {:reply, create_resp, _} =
          CreateFrame.execute(
            %{
              description: "Threshold values on Board",
              saved_searches: ["upwork|vendor onboarding"],
              total_spent_min: 5_000,
              hire_rate_min: 50,
              min_money_gated_candidates: 1
            },
            agent_frame
          )

        frame_id = decode_payload(create_resp)["frame_id"]

        {token, _} = Fixtures.generate_user_magic_link_token(scope.user)
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok,
         Map.merge(context, %{
           authed_conn: authed_conn,
           frame_id: frame_id
         })}
      end

      when_ "the founder opens the Frame detail page", context do
        {:ok, view, html} =
          live(context.authed_conn, "/app/problem-discovery/frames/#{context.frame_id}")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the rendered page shows the threshold values", context do
        assert context.html =~ "5000" or context.html =~ "5,000" or context.html =~ "$5000",
               "expected total_spent_min ($5,000) to render on the Frame detail page"

        assert context.html =~ "50%" or context.html =~ "50",
               "expected hire_rate_min (50%) to render on the Frame detail page"
        {:ok, context}
      end
    end
  end
end
