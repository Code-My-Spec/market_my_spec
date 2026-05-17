defmodule MarketMySpecSpex.Story707.Criterion6407Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6407 — Agent calls stage_response and receives the new
  Touchpoint id.

  Sister to 6398; pinned via Three Amigos scenario. Same happy-path
  contract, expressed as Sam's perspective: the agent receives back
  the id of the row it just created and can use it for subsequent
  list_touchpoints / update_touchpoint calls.

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

  spex "stage_response returns the new Touchpoint id (round-trippable)" do
    scenario "Sam dictates → agent polishes → stage_response → id usable in list_touchpoints" do
      given_ "a persisted Reddit Thread (sub: elixir)", context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "tp407",
            subreddit: "elixir"
          })

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent calls stage_response with Sam's polished body and link_target", context do
        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "Sam's polished body referencing https://marketmyspec.com/x",
              link_target: "https://marketmyspec.com/x"
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

      then_ "returned id is a UUID and is round-trippable via list_touchpoints", context do
        assert uuid?(context.touchpoint_id),
               "expected UUID Touchpoint id, got: #{inspect(context.touchpoint_id)}"

        touchpoints = context.list_payload["touchpoints"] || context.list_payload["list"] || []
        ids = Enum.map(touchpoints, &(&1["id"] || &1[:id]))

        assert context.touchpoint_id in ids,
               "expected returned id present in list_touchpoints; got ids: #{inspect(ids)}"

        {:ok, context}
      end
    end
  end
end
