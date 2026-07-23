defmodule MarketMySpecSpex.Story707.Criterion6501Spex do
  @moduledoc """
  Story 707 — Stage a Touchpoint from a Thread (synopsis, angle, UTM link)
  Criterion 6501 — Agent stages with synopsis and angle, receives
  round-trippable Touchpoint id.

  Happy-path entry: agent calls stage_response with the new signature
  (thread_id, synopsis, angle). The tool returns a payload containing
  the new Touchpoint id (a UUID) and the same id is round-trippable
  via list_touchpoints on the same thread_id.

  Interaction surface: MCP tool execution (agent surface).
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

  defp uuid?(value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp uuid?(_), do: false

  spex "stage_response returns the new Touchpoint id round-trippable via list_touchpoints" do
    scenario "Agent stages with synopsis and angle; receives a UUID present in list_touchpoints" do
      given_ "a persisted Reddit Thread owned by Sam's account", context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rt6501",
            subreddit: "elixir"
          })

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent calls stage_response with thread_id, synopsis, and angle", context do
        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              synopsis: "OP is asking how to integrate Ash into an existing Phoenix project.",
              angle: "Suggest an incremental migration starting with a single context."
            },
            context.frame
          )

        payload = decode_payload(stage_resp)
        touchpoint_id = payload["touchpoint_id"] || payload["id"]

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           touchpoint_id: touchpoint_id,
           list_payload: decode_payload(list_resp)
         })}
      end

      then_ "the response carries a UUID and list_touchpoints includes it", context do
        assert uuid?(context.touchpoint_id),
               "expected payload to carry a UUID Touchpoint id, got: #{inspect(context.touchpoint_id)}"

        touchpoints = context.list_payload["touchpoints"] || context.list_payload["list"] || []
        ids = Enum.map(touchpoints, &(&1["id"] || &1[:id]))

        assert context.touchpoint_id in ids,
               "expected returned id present in list_touchpoints; got ids: #{inspect(ids)}"

        {:ok, context}
      end
    end
  end
end
