defmodule MarketMySpecSpex.Story716.Criterion6358Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6358 — LiveView paste-URL flow and update_touchpoint MCP
  call leave identical persisted state.

  Sister to 6341; pinned via Three Amigos scenario. Operator flow:
  click "Mark posted" → paste URL into a form → submit → form posts
  through the same context function backing update_touchpoint (not
  bypassing it). After submit: list_touchpoints reflects :posted, the
  pasted URL, and a posted_at timestamp — same as if the agent had
  called update_touchpoint directly.

  Interaction surface: LiveView UI (operator surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints
  alias MarketMySpec.McpServers.Engagements.Tools.StageResponse
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

  spex "paste-URL form executes update_touchpoint under the hood" do
    scenario "Mark posted → paste URL → submit; list reflects :posted with pasted URL + timestamp" do
      given_ "a staged Touchpoint visible in TouchpointLive.Show for the logged-in operator",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "ui360"})
        frame = build_frame(scope)

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              polished_body: "Body for paste-URL test",
              link_target: "https://marketmyspec.com/x"
            },
            frame
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        token = MarketMySpec.Users.generate_user_session_token(scope.user)

        conn =
          Phoenix.ConnTest.build_conn()
          |> Phoenix.ConnTest.init_test_session(%{})
          |> Plug.Conn.put_session(:user_token, token)

        {:ok,
         Map.merge(context, %{
           conn: conn,
           scope: scope,
           frame: frame,
           thread: thread,
           touchpoint_id: touchpoint_id
         })}
      end

      when_ "operator opens the touchpoint, pastes the live URL, submits the form", context do
        pasted_url = "https://www.reddit.com/r/elixir/comments/ui360/_/xyz"

        ui_path =
          "/accounts/#{context.scope.active_account_id}/touchpoints/#{context.touchpoint_id}"

        case Phoenix.LiveViewTest.live(context.conn, ui_path) do
          {:ok, view, _html} ->
            view
            |> Phoenix.LiveViewTest.form("[data-test='mark-posted-form']", %{
              "touchpoint" => %{"comment_url" => pasted_url}
            })
            |> Phoenix.LiveViewTest.render_submit()

            :ok

          {:error, reason} ->
            flunk(
              "expected TouchpointLive.Show reachable at #{ui_path}; " <>
                "got: #{inspect(reason)}"
            )
        end

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           pasted_url: pasted_url,
           payload: decode_payload(list_resp)
         })}
      end

      then_ "the touchpoint is :posted with the pasted URL and a posted_at timestamp", context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []
        tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.touchpoint_id))
        assert tp, "expected touchpoint in list after UI submit"

        assert (tp["state"] || tp[:state]) in ["posted", :posted],
               "expected state :posted after UI submit, got: #{inspect(tp["state"] || tp[:state])}"

        assert (tp["comment_url"] || tp[:comment_url]) == context.pasted_url,
               "expected pasted URL persisted; got: #{inspect(tp["comment_url"] || tp[:comment_url])}"

        assert (tp["posted_at"] || tp[:posted_at]) != nil,
               "expected posted_at populated by UI flow"

        {:ok, context}
      end
    end
  end
end
