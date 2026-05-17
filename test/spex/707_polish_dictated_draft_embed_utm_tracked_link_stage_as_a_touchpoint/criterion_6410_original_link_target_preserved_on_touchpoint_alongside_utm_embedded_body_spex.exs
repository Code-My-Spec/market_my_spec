defmodule MarketMySpecSpex.Story707.Criterion6410Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6410 — Original link_target preserved on the Touchpoint
  alongside the UTM-embedded body.

  Sister to 6403; pinned via Three Amigos scenario. Two surfaces on
  the same row: `polished_body` carries the UTM-embedded URL, while
  `link_target` carries the un-decorated original. Both come back from
  list_touchpoints.

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

  spex "row carries un-decorated link_target alongside UTM-embedded body" do
    scenario "list_touchpoints returns both fields; link_target is original, polished_body has UTM URL" do
      given_ "a Reddit Thread (sub: elixir)", context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "tp410",
            subreddit: "elixir"
          })

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent stages with a specific link_target", context do
        link_target = "https://marketmyspec.com/manifesto"

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "Read: " <> link_target,
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
           payload: decode_payload(list_resp)
         })}
      end

      then_ "row.link_target == original (un-UTM'd); row.polished_body carries UTM URL", context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []
        tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.touchpoint_id))
        assert tp, "expected touchpoint in list"

        link_target_field = tp["link_target"] || tp[:link_target]
        polished_body = tp["polished_body"] || tp[:polished_body]

        assert link_target_field == context.original_link,
               "expected link_target field == original URL; got: #{inspect(link_target_field)}"

        refute link_target_field =~ "utm_source",
               "expected link_target field to be un-UTM'd (audit); got: #{link_target_field}"

        assert polished_body =~ "utm_source=reddit",
               "expected polished_body to carry UTM-embedded URL; got: #{polished_body}"

        {:ok, context}
      end
    end
  end
end
