defmodule MarketMySpecSpex.Story707.Criterion6403Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6403 — The original (un-UTM'd) `link_target` URL is stored
  on the Touchpoint as `link_target` for reference and audit.

  Audit trail: even though the body carries the UTM-embedded URL, the
  Touchpoint row carries the original un-decorated URL on a separate
  `link_target` field. Useful for re-keying campaigns or auditing what
  the agent originally asked for.

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

  spex "Touchpoint row carries original (un-UTM'd) link_target for audit" do
    scenario "Stage → list → link_target column equals the original URL exactly" do
      given_ "a persisted Reddit Thread", context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "aud403",
            subreddit: "elixir"
          })

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent stages with a specific link_target", context do
        link_target = "https://marketmyspec.com/founders/harness"

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "See " <> link_target <> " for the writeup.",
              link_target: link_target
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
           original_link: link_target,
           touchpoint_id: touchpoint_id,
           list_payload: decode_payload(list_resp)
         })}
      end

      then_ "Touchpoint row carries link_target exactly equal to the original URL", context do
        touchpoints = context.list_payload["touchpoints"] || context.list_payload["list"] || []
        tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.touchpoint_id))
        assert tp, "expected touchpoint in list"

        stored_link = tp["link_target"] || tp[:link_target]

        assert stored_link == context.original_link,
               "expected link_target column to equal original URL; got: #{inspect(stored_link)}"

        refute stored_link =~ "utm_source",
               "expected link_target column to be un-UTM'd (audit); got: #{stored_link}"

        {:ok, context}
      end
    end
  end
end
