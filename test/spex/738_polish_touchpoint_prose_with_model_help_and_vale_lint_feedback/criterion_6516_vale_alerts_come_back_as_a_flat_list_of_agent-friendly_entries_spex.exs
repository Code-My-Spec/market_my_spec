defmodule MarketMySpecSpex.Story738.Criterion6516Spex do
  @moduledoc """
  Story 738 — Polish Touchpoint prose with model help and Vale lint feedback
  Criterion 6516 — Vale alerts come back as a flat list of agent-friendly
  entries.

  When polish_touchpoint returns Vale alerts, the response shape is a flat
  list of entries — each entry carrying `severity`, `check`, `line`,
  `column`, and `message` — NOT Vale's raw JSON-by-file-path map. The
  agent reading the response can act on individual alerts directly without
  unwrapping a file-path keyed structure.

  Interaction surface: MCP tool execution (agent surface) with LiveView
  setup for the saved configuration.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
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

  spex "Vale alerts are a flat list of agent-friendly entries" do
    scenario "Saved config triggers alerts; response is a flat list with severity/check/line/column/message" do
      given_ "Sam has saved a .vale.ini that will trigger alerts and a staged Touchpoint", context do
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
            source_thread_id: "rt6516",
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

        {:ok, Map.merge(context, %{frame: frame, touchpoint_id: touchpoint_id})}
      end

      when_ "agent calls polish_touchpoint with prose that triggers a write-good alert", context do
        {:reply, polish_resp, _} =
          PolishTouchpoint.execute(
            %{
              touchpoint_id: context.touchpoint_id,
              polished_body: "This is very interesting and very useful."
            },
            context.frame
          )

        {:ok, Map.put(context, :polish_payload, decode_payload(polish_resp))}
      end

      then_ "each alert is a flat map with severity, check, line, column, and message", context do
        alerts = context.polish_payload["alerts"] || context.polish_payload[:alerts] || []

        assert is_list(alerts) and alerts != [],
               "expected non-empty alerts list; got: #{inspect(alerts)}"

        Enum.each(alerts, fn alert ->
          assert is_map(alert), "expected each alert to be a map; got: #{inspect(alert)}"

          severity = alert["severity"] || alert[:severity]
          check = alert["check"] || alert[:check]
          line = alert["line"] || alert[:line]
          column = alert["column"] || alert[:column]
          message = alert["message"] || alert[:message]

          assert is_binary(severity), "expected alert.severity to be a string; got: #{inspect(severity)}"
          assert is_binary(check), "expected alert.check to be a string; got: #{inspect(check)}"
          assert is_integer(line), "expected alert.line to be an integer; got: #{inspect(line)}"
          assert is_integer(column), "expected alert.column to be an integer; got: #{inspect(column)}"
          assert is_binary(message), "expected alert.message to be a string; got: #{inspect(message)}"
        end)

        refute is_map(context.polish_payload["alerts"]) and not is_list(context.polish_payload["alerts"]),
               "expected alerts to be a flat list, not Vale's raw JSON-by-file-path map; got: #{inspect(context.polish_payload["alerts"])}"

        {:ok, context}
      end
    end
  end
end
