defmodule MarketMySpecSpex.Story707.Criterion6400Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6400 — The created Touchpoint has state `:staged`
  (per story 716 R1's default for new Touchpoints).

  Default state on stage_response is :staged — never :posted, never
  :abandoned, never inferred from any other field. list_touchpoints
  reads back :staged for the newly-created row.

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

  spex "new Touchpoint defaults to state :staged" do
    scenario "Stage → list → state :staged with no comment_url and no posted_at" do
      given_ "a persisted Thread", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "stg400"})
        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent calls stage_response then list_touchpoints", context do
        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "Body https://x",
              link_target: "https://x"
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

      then_ "the row is :staged; comment_url and posted_at are nil", context do
        touchpoints = context.list_payload["touchpoints"] || context.list_payload["list"] || []
        tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.touchpoint_id))
        assert tp, "expected newly-staged touchpoint in list"

        assert (tp["state"] || tp[:state]) in ["staged", :staged],
               "expected default state :staged, got: #{inspect(tp["state"] || tp[:state])}"

        assert (tp["comment_url"] || tp[:comment_url]) == nil,
               "expected comment_url nil on staged touchpoint"

        assert (tp["posted_at"] || tp[:posted_at]) == nil,
               "expected posted_at nil on staged touchpoint"

        {:ok, context}
      end
    end
  end
end
