defmodule MarketMySpecSpex.Story716.Criterion6471Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Scenario 6471 — Agent revision propagates to an open touchpoint page
  without refresh.

  Rule: when the agent updates a touchpoint via MCP, any open
  TouchpointLive.Show for that touchpoint reflects the new values in
  real-time (form fields + parent thread synopsis) — no page refresh.

  Setup: stage a touchpoint, mount TouchpointLive.Show as the operator,
  then have the "agent" call update_touchpoint via MCP. Render the live
  view again; the form textareas should contain the new values, and the
  DB row should match.

  Interaction surface: LiveView + MCP cross-surface real-time propagation.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements
  alias MarketMySpec.McpServers.Engagements.Tools.StageResponse
  alias MarketMySpec.McpServers.Engagements.Tools.UpdateTouchpoint
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

  spex "agent update_touchpoint propagates to open LiveView form without refresh" do
    scenario "operator on Show, agent revises body+angle, page re-renders new values" do
      given_ "a staged touchpoint with a first draft and the operator viewing it", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "rt471"})
        frame = build_frame(scope)

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              polished_body: "first draft body",
              angle: "first angle",
              link_target: "https://marketmyspec.com/x"
            },
            frame
          )

        touchpoint_id = (decode_payload(stage_resp))["touchpoint_id"]

        token = MarketMySpec.Users.generate_user_session_token(scope.user)

        conn =
          Phoenix.ConnTest.build_conn()
          |> Phoenix.ConnTest.init_test_session(%{})
          |> Plug.Conn.put_session(:user_token, token)

        path =
          "/accounts/#{scope.active_account_id}/touchpoints/#{touchpoint_id}"

        {:ok, view, initial_html} = Phoenix.LiveViewTest.live(conn, path)

        {:ok,
         Map.merge(context, %{
           scope: scope,
           frame: frame,
           thread: thread,
           touchpoint_id: touchpoint_id,
           view: view,
           initial_html: initial_html
         })}
      end

      when_ "the agent calls update_touchpoint via MCP with a revised body and angle", context do
        revised_body = "REVISED body from the agent"
        revised_angle = "REVISED angle from the agent"

        {:reply, _resp, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: context.touchpoint_id,
              polished_body: revised_body,
              angle: revised_angle
            },
            context.frame
          )

        rerendered = Phoenix.LiveViewTest.render(context.view)

        {:ok, reloaded} = Engagements.get_touchpoint_by_id(context.scope, context.touchpoint_id)

        {:ok,
         Map.merge(context, %{
           revised_body: revised_body,
           revised_angle: revised_angle,
           rerendered: rerendered,
           reloaded: reloaded
         })}
      end

      then_ "the LiveView form textareas show the revised values without a refresh, and the DB row matches",
            context do
        assert context.initial_html =~ "first draft body",
               "sanity: initial render should have shown the first draft"

        assert context.rerendered =~ context.revised_body,
               "expected the re-rendered LiveView to contain the revised polished_body without a refresh"

        assert context.rerendered =~ context.revised_angle,
               "expected the re-rendered LiveView to contain the revised angle without a refresh"

        refute context.rerendered =~ "first draft body",
               "expected the old body to be gone from the re-rendered page"

        assert context.reloaded.polished_body == context.revised_body,
               "expected the DB row to match the agent's revision; got: #{inspect(context.reloaded.polished_body)}"

        assert context.reloaded.angle == context.revised_angle,
               "expected the DB row to match the agent's revision; got: #{inspect(context.reloaded.angle)}"

        {:ok, context}
      end
    end
  end
end
