defmodule MarketMySpecSpex.Story738.Criterion6519Spex do
  @moduledoc """
  Story 738 — Polish Touchpoint prose with model help and Vale lint feedback
  Criterion 6519 — Lint alerts block the write and return alerts to the
  agent.

  Sam has a saved Vale config. The agent calls polish_touchpoint with
  prose that violates one or more configured rules. The lint returns a
  non-empty alert list, and (per R2a) the polished_body is NOT written
  to the Touchpoint — the Touchpoint's polished_body stays at whatever
  it was before the call. The agent receives the alerts and is expected
  to revise prose and retry.

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

  spex "lint alerts block the write; response carries alerts; Touchpoint body unchanged" do
    scenario "Saved config; prose violates a rule; alerts returned; Touchpoint polished_body unchanged" do
      given_ "Sam has saved a .vale.ini with write-good and a staged Touchpoint (polished_body nil)", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = build_frame(scope)

        {token, _} = Fixtures.generate_user_magic_link_token(scope.user)
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, view, _} = live(authed_conn, "/accounts/#{scope.active_account_id}/style-guide")

        view
        |> form("[data-test='style-guide-form']",
          style_guide: %{vale_ini: @vale_ini_with_writegood}
        )
        |> render_submit()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rt6519",
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

      when_ "agent calls polish_touchpoint with prose containing write-good violations", context do
        offending_body = "This is very useful and very interesting overall."

        {:reply, polish_resp, _} =
          PolishTouchpoint.execute(
            %{touchpoint_id: context.touchpoint_id, polished_body: offending_body},
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
           offending_body: offending_body,
           polish_payload: decode_payload(polish_resp),
           touchpoint: tp
         })}
      end

      then_ "alerts are returned and the Touchpoint's polished_body is unchanged (still nil)", context do
        alerts = context.polish_payload["alerts"] || context.polish_payload[:alerts] || []

        assert is_list(alerts) and alerts != [],
               "expected non-empty alerts list when prose violates rules; got: #{inspect(alerts)}"

        assert context.touchpoint, "expected the staged Touchpoint in list_touchpoints"

        stored = context.touchpoint["polished_body"] || context.touchpoint[:polished_body]

        assert stored == nil,
               "expected polished_body unchanged (still nil) when alerts blocked the write; got: #{inspect(stored)}"

        refute stored == context.offending_body,
               "expected offending prose NOT to be persisted on alert-blocked polish"

        {:ok, context}
      end
    end
  end
end
