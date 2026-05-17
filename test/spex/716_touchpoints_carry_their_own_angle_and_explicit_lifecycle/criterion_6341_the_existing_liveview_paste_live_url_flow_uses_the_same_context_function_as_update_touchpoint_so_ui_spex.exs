defmodule MarketMySpecSpex.Story716.Criterion6341Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6341 — The existing LiveView "paste live URL" flow uses the
  same context function as `update_touchpoint` so UI and agent surfaces
  transition state identically.

  Equivalence test: stage two identical Touchpoints (TP-ui, TP-agent),
  transition TP-ui via the LiveView paste-URL form and TP-agent via the
  MCP update_touchpoint tool, both with the same comment_url + posted_at.
  After both transitions, list_touchpoints returns identical
  state/comment_url/posted_at for both rows (proving they ran through
  the same context function).

  Interaction surface: LiveView (Sam) + MCP tool (agent) — same context
  function backs both.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints
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

  spex "LiveView paste-URL flow and update_touchpoint MCP call produce identical persisted state" do
    scenario "Two identical Touchpoints transition via different surfaces; result is identical" do
      given_ "an account with two identically-staged Touchpoints (TP-ui and TP-agent)",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "eq001"})
        frame = build_frame(scope)

        stage = fn body ->
          {:reply, resp, _} =
            StageResponse.execute(
              %{thread_id: thread.id, polished_body: body, link_target: "https://x",
                angle: "Equivalence test"},
              frame
            )

          decoded = decode_payload(resp)
          decoded["touchpoint_id"] || decoded["id"]
        end

        id_ui = stage.("Body ui")
        id_agent = stage.("Body agent")

        conn = Phoenix.ConnTest.build_conn()

        {:ok,
         Map.merge(context, %{
           conn: conn,
           scope: scope,
           frame: frame,
           thread: thread,
           id_ui: id_ui,
           id_agent: id_agent
         })}
      end

      when_ "TP-ui transitions via the LiveView paste-URL form; TP-agent via update_touchpoint",
            context do
        common_url = "https://www.reddit.com/r/elixir/comments/eq001/_/posted_xyz"
        common_posted_at = DateTime.utc_now() |> DateTime.truncate(:second)
        posted_at_iso = DateTime.to_iso8601(common_posted_at)

        # LiveView flow: Sam navigates to the touchpoint detail page and
        # pastes the live URL. The auth pipeline derives the scope from
        # :user_token in session, so we log the user in via the same path
        # the conn_case helper uses.
        token = MarketMySpec.Users.generate_user_session_token(context.scope.user)

        conn =
          context.conn
          |> Phoenix.ConnTest.init_test_session(%{})
          |> Plug.Conn.put_session(:user_token, token)

        ui_path =
          "/accounts/#{context.scope.active_account_id}/touchpoints/#{context.id_ui}"

        case Phoenix.LiveViewTest.live(conn, ui_path) do
          {:ok, view, _html} ->
            # Submit the "paste live URL" form. data-test attribute pinned
            # by TouchpointLive.Show spec.
            view
            |> Phoenix.LiveViewTest.form("[data-test='mark-posted-form']", %{
              "touchpoint" => %{"comment_url" => common_url, "posted_at" => posted_at_iso}
            })
            |> Phoenix.LiveViewTest.render_submit()

            :ok

          {:error, reason} ->
            flunk(
              "expected TouchpointLive.Show to be reachable at #{ui_path}; " <>
                "got LiveView error: #{inspect(reason)}"
            )
        end

        # Agent MCP flow on TP-agent
        {:reply, _, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: context.id_agent,
              state: "posted",
              comment_url: common_url,
              posted_at: posted_at_iso
            },
            context.frame
          )

        # List both for comparison
        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok, Map.put(context, :payload, decode_payload(list_resp))}
      end

      then_ "TP-ui and TP-agent end in identical persisted state", context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []
        assert length(touchpoints) == 2

        tp_ui = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.id_ui))
        tp_agent = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.id_agent))

        assert tp_ui, "expected TP-ui in list"
        assert tp_agent, "expected TP-agent in list"

        for key <- ~w(state comment_url posted_at) do
          assert tp_ui[key] == tp_agent[key],
                 "expected #{key} identical across surfaces; ui=#{inspect(tp_ui[key])}, agent=#{inspect(tp_agent[key])}"
        end

        # And the transition succeeded in both cases
        assert tp_ui["state"] in ["posted", :posted],
               "expected TP-ui :posted, got: #{inspect(tp_ui["state"])}"

        assert tp_agent["state"] in ["posted", :posted],
               "expected TP-agent :posted, got: #{inspect(tp_agent["state"])}"

        {:ok, context}
      end
    end
  end
end
