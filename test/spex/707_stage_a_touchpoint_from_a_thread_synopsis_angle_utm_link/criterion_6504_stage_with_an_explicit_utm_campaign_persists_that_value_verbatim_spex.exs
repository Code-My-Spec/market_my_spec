defmodule MarketMySpecSpex.Story707.Criterion6504Spex do
  @moduledoc """
  Story 707 — Stage a Touchpoint from a Thread (synopsis, angle, UTM link)
  Criterion 6504 — Stage with an explicit utm_campaign persists that
  value verbatim.

  The agent passes utm_campaign="custom-tag-2026"; the touchpoint stores
  exactly "custom-tag-2026" — no munging, no slug normalization, no
  default fallback applied.

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

  spex "explicit utm_campaign is stored verbatim, overriding the default" do
    scenario "Agent passes utm_campaign=custom-tag-2026 → touchpoint stores custom-tag-2026" do
      given_ "a Reddit thread (default would be elixir:rt6504 absent override)", context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rt6504",
            subreddit: "elixir"
          })

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent stages with an explicit utm_campaign override", context do
        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              synopsis: "OP asks about pattern matching in function heads.",
              angle: "Lead with the readability win versus case statements.",
              utm_campaign: "custom-tag-2026"
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

      then_ "the touchpoint's utm_campaign equals custom-tag-2026 exactly", context do
        assert context.touchpoint, "expected touchpoint in list"

        assert field(context.touchpoint, "utm_campaign") == "custom-tag-2026",
               "expected utm_campaign=custom-tag-2026, got: #{inspect(field(context.touchpoint, "utm_campaign"))}"

        {:ok, context}
      end
    end
  end
end
