defmodule MarketMySpecSpex.Story707.Criterion6509Spex do
  @moduledoc """
  Story 707 — Stage a Touchpoint from a Thread (synopsis, angle, UTM link)
  Criterion 6509 — New Touchpoint defaults to state :staged with nil
  comment_url and nil posted_at.

  Lifecycle inheritance from story 716: every Touchpoint created by
  stage_response begins in state :staged. comment_url and posted_at are
  both nil on create — they are populated when the founder transitions
  the Touchpoint to :posted via update_touchpoint or the LiveView form.

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

  defp touchpoint_for(payload, id) do
    touchpoints = payload["touchpoints"] || payload["list"] || []
    Enum.find(touchpoints, &((&1["id"] || &1[:id]) == id))
  end

  defp field(tp, key), do: tp[key] || tp[String.to_atom(key)]

  spex "new Touchpoint defaults to :staged with nil comment_url and posted_at" do
    scenario "Stage → list → row carries state=:staged, comment_url=nil, posted_at=nil" do
      given_ "a Reddit thread owned by Sam", context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rt6509",
            subreddit: "elixir"
          })

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent calls stage_response, then lists touchpoints", context do
        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              synopsis: "OP asks about hot code reloading.",
              angle: "Point to the distillery escape-hatch playbook."
            },
            context.frame
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           touchpoint: touchpoint_for(decode_payload(list_resp), touchpoint_id)
         })}
      end

      then_ "the touchpoint state is :staged; comment_url and posted_at are nil", context do
        assert context.touchpoint, "expected newly-staged touchpoint in list"

        assert field(context.touchpoint, "state") in ["staged", :staged],
               "expected default state :staged, got: #{inspect(field(context.touchpoint, "state"))}"

        assert field(context.touchpoint, "comment_url") == nil,
               "expected comment_url nil on staged touchpoint"

        assert field(context.touchpoint, "posted_at") == nil,
               "expected posted_at nil on staged touchpoint"

        {:ok, context}
      end
    end
  end
end
