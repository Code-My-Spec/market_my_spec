defmodule MarketMySpecSpex.Story738.Criterion6512Spex do
  @moduledoc """
  Story 738 — Polish Touchpoint prose with model help and Vale lint feedback
  Criterion 6512 — Vale lints against the account's saved configuration.

  Sam saves a `.vale.ini` enabling write-good (which flags weasel words
  like "very"). An agent stages a Touchpoint on Sam's account and calls
  polish_touchpoint with prose containing "very". The lint runs against
  Sam's saved configuration and the returned alert list flags the weasel
  word — proving the saved configuration is the one in use.

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

  spex "polish_touchpoint runs Vale against the account's saved configuration" do
    scenario "Save .vale.ini with write-good; polish prose with 'very'; alert flags it" do
      given_ "Sam has saved a .vale.ini enabling write-good and has a staged Touchpoint", context do
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
            source_thread_id: "rt6512",
            subreddit: "elixir"
          })

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              synopsis: "OP asks for advice.",
              angle: "Suggest a measured response."
            },
            frame
          )

        touchpoint_id = (decode_payload(stage_resp))["touchpoint_id"]

        {:ok, Map.merge(context, %{frame: frame, touchpoint_id: touchpoint_id})}
      end

      when_ "agent calls polish_touchpoint with prose containing the weasel word 'very'", context do
        {:reply, polish_resp, _} =
          PolishTouchpoint.execute(
            %{
              touchpoint_id: context.touchpoint_id,
              polished_body: "I think this is a very good idea overall."
            },
            context.frame
          )

        {:ok, Map.put(context, :polish_payload, decode_payload(polish_resp))}
      end

      then_ "the alert list flags the weasel word per the saved configuration", context do
        alerts = context.polish_payload["alerts"] || context.polish_payload[:alerts] || []

        assert is_list(alerts) and alerts != [],
               "expected non-empty alerts list from polish_touchpoint; got: #{inspect(alerts)}"

        assert Enum.any?(alerts, fn alert ->
                 check = alert["check"] || alert[:check] || ""
                 message = alert["message"] || alert[:message] || ""
                 String.contains?(check, "write-good") or
                   String.contains?(message, "very") or
                   String.contains?(message, "weasel")
               end),
               "expected at least one alert from write-good (weasel word); got: #{inspect(alerts)}"

        {:ok, context}
      end
    end
  end
end
