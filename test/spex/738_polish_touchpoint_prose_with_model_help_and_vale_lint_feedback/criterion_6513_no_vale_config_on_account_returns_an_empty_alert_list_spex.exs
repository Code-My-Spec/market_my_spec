defmodule MarketMySpecSpex.Story738.Criterion6513Spex do
  @moduledoc """
  Story 738 — Polish Touchpoint prose with model help and Vale lint feedback
  Criterion 6513 — No Vale config on account returns an empty alert list.

  When the account has no saved Vale configuration, polish_touchpoint
  treats the lint as advisory-only with no rules to apply. The tool
  returns an empty alert list and (since alerts are empty, per R2a) the
  polished body is written to the Touchpoint.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.PolishTouchpoint
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

  spex "polish_touchpoint returns an empty alert list when no Vale config is saved" do
    scenario "No saved config → polish with any prose → response carries empty alerts" do
      given_ "Sam has a staged Touchpoint and no Vale config saved on his Account", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = build_frame(scope)

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rt6513",
            subreddit: "elixir"
          })

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              synopsis: "OP asks for a recommendation.",
              angle: "Point to the obvious answer."
            },
            frame
          )

        touchpoint_id = (decode_payload(stage_resp))["touchpoint_id"]

        {:ok, Map.merge(context, %{frame: frame, touchpoint_id: touchpoint_id})}
      end

      when_ "agent calls polish_touchpoint with arbitrary prose", context do
        {:reply, polish_resp, _} =
          PolishTouchpoint.execute(
            %{
              touchpoint_id: context.touchpoint_id,
              polished_body:
                "Some prose with very loose phrasing and several weasel words that a config WOULD flag if one were saved."
            },
            context.frame
          )

        {:ok, Map.put(context, :polish_payload, decode_payload(polish_resp))}
      end

      then_ "the response carries an empty alert list", context do
        alerts = context.polish_payload["alerts"] || context.polish_payload[:alerts]

        assert alerts == [],
               "expected empty alerts list when no Vale config is saved; got: #{inspect(alerts)}"

        {:ok, context}
      end
    end
  end
end
