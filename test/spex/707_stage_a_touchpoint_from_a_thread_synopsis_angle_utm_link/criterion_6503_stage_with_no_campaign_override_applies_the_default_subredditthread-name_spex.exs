defmodule MarketMySpecSpex.Story707.Criterion6503Spex do
  @moduledoc """
  Story 707 — Stage a Touchpoint from a Thread (synopsis, angle, UTM link)
  Criterion 6503 — Stage with no campaign override applies the default
  `<subreddit>:<thread-name>` for Reddit (and `<category-slug>:<thread-name>`
  for ElixirForum).

  When the agent omits utm_campaign on stage_response, the app derives a
  default of the form `<subreddit>:<thread-name>` for a Reddit thread
  (using the parent Thread's subreddit and source_thread_id as the
  thread-name) and `<category-slug>:<thread-name>` for an ElixirForum
  thread.

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

  spex "default utm_campaign matches <source-identifier>:<thread-name>" do
    scenario "Reddit thread with no campaign override → utm_campaign=elixir:rt6503" do
      given_ "a Reddit thread in r/elixir with source_thread_id rt6503", context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rt6503",
            subreddit: "elixir"
          })

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent stages without an explicit utm_campaign", context do
        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              synopsis: "OP asks about hot code reloading in releases.",
              angle: "Recommend distillery escape hatch or staging hot reload."
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

      then_ "the touchpoint's utm_campaign defaults to elixir:rt6503", context do
        assert context.touchpoint, "expected touchpoint in list"

        assert field(context.touchpoint, "utm_campaign") == "elixir:rt6503",
               "expected utm_campaign=elixir:rt6503, got: #{inspect(field(context.touchpoint, "utm_campaign"))}"

        {:ok, context}
      end
    end
  end
end
