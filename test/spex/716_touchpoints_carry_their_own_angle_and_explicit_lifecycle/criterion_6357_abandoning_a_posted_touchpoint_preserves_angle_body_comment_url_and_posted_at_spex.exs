defmodule MarketMySpecSpex.Story716.Criterion6357Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6357 — Abandoning a posted Touchpoint preserves angle,
  body, comment_url, and posted_at.

  Sister to 6336; pinned via Three Amigos scenario. Stage → :posted →
  :abandoned. Post-abandon, all four metadata fields remain intact.

  Interaction surface: MCP tool execution (agent surface).
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

  spex "abandoning a posted Touchpoint preserves angle, body, comment_url, posted_at" do
    scenario "Posted touchpoint → abandoned; all four metadata fields preserved" do
      given_ "a touchpoint stage→post with known fields", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "abd357"})
        frame = build_frame(scope)

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              polished_body: "Polished body to preserve",
              link_target: "https://marketmyspec.com/x",
              angle: "Angle to preserve"
            },
            frame
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        comment_url = "https://www.reddit.com/r/elixir/comments/abd357/_/xyz"
        posted_at = DateTime.utc_now() |> DateTime.truncate(:second)

        {:reply, _, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: touchpoint_id,
              state: "posted",
              comment_url: comment_url,
              posted_at: DateTime.to_iso8601(posted_at)
            },
            frame
          )

        {:ok,
         Map.merge(context, %{
           frame: frame,
           thread: thread,
           touchpoint_id: touchpoint_id,
           comment_url: comment_url,
           posted_at: posted_at
         })}
      end

      when_ "agent transitions to :abandoned and lists", context do
        {:reply, _, _} =
          UpdateTouchpoint.execute(
            %{touchpoint_id: context.touchpoint_id, state: "abandoned"},
            context.frame
          )

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok, Map.put(context, :payload, decode_payload(list_resp))}
      end

      then_ "Touchpoint state :abandoned; angle/body/comment_url/posted_at all preserved",
            context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []
        refute Enum.empty?(touchpoints)
        tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.touchpoint_id))
        assert tp, "expected touchpoint preserved (non-destructive abandon)"

        assert (tp["state"] || tp[:state]) in ["abandoned", :abandoned]
        assert (tp["angle"] || tp[:angle]) == "Angle to preserve"
        assert (tp["polished_body"] || tp[:polished_body]) == "Polished body to preserve"
        assert (tp["comment_url"] || tp[:comment_url]) == context.comment_url
        assert (tp["posted_at"] || tp[:posted_at]) != nil

        {:ok, context}
      end
    end
  end
end
