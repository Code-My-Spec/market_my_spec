defmodule MarketMySpecSpex.Story738.Criterion6517Spex do
  @moduledoc """
  Story 738 — Polish Touchpoint prose with model help and Vale lint feedback
  Criterion 6517 — Clean prose writes polished_body and returns no alerts.

  Sam has a saved Vale config. The agent calls polish_touchpoint with
  prose that violates no configured rules. The lint returns an empty
  alert list, and (per R2a) the polished_body is written to the
  Touchpoint. Observable via list_touchpoints.

  Interaction surface: MCP tool execution (agent surface) with LiveView
  setup for the saved configuration.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints
  alias MarketMySpec.McpServers.Engagements.Tools.PolishTouchpoint
  alias MarketMySpec.McpServers.Engagements.Tools.StageResponse
  alias MarketMySpecSpex.Fixtures

  @vale_ini_with_writegood """
  StylesPath = /app/priv/vale/styles
  MinAlertLevel = warning

  [*.md]
  BasedOnStyles = write-good
  """

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

  spex "clean prose writes polished_body and returns no alerts" do
    scenario "Saved config; prose violates nothing; body is persisted; alerts empty" do
      given_ "Sam has saved a .vale.ini and a staged Touchpoint", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = build_frame(scope)

        {token, _} = Fixtures.generate_user_magic_link_token(scope.user)
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, view, _} = live(authed_conn, "/app/accounts/#{scope.active_account_id}/style-guide")

        view
        |> form("[data-test='style-guide-form']",
          style_guide: %{vale_ini: @vale_ini_with_writegood}
        )
        |> render_submit()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rt6517",
            subreddit: "elixir"
          })

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              synopsis: "OP synopsis.",
              angle: "Angle."
            },
            frame
          )

        touchpoint_id = (decode_payload(stage_resp))["touchpoint_id"]

        {:ok, Map.merge(context, %{frame: frame, thread: thread, touchpoint_id: touchpoint_id})}
      end

      when_ "agent calls polish_touchpoint with prose that triggers no write-good rules", context do
        polished_body = "A short reply offering specific guidance without any flagged words."

        {:reply, polish_resp, _} =
          PolishTouchpoint.execute(
            %{touchpoint_id: context.touchpoint_id, polished_body: polished_body},
            context.frame
          )

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        touchpoints =
          (decode_payload(list_resp))["touchpoints"] ||
            (decode_payload(list_resp))["list"] || []

        tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.touchpoint_id))

        {:ok,
         Map.merge(context, %{
           polished_body: polished_body,
           polish_payload: decode_payload(polish_resp),
           touchpoint: tp
         })}
      end

      then_ "the response carries an empty alert list and the Touchpoint stores the body", context do
        alerts = context.polish_payload["alerts"] || context.polish_payload[:alerts]

        assert alerts == [],
               "expected empty alerts list for clean prose; got: #{inspect(alerts)}"

        assert context.touchpoint, "expected the touchpoint in list_touchpoints"

        stored = context.touchpoint["polished_body"] || context.touchpoint[:polished_body]

        assert stored == context.polished_body,
               "expected polished_body persisted verbatim when alerts are empty; got: #{inspect(stored)}"

        {:ok, context}
      end
    end
  end
end
