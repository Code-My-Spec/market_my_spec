defmodule MarketMySpecSpex.Story716.Criterion6338Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6338 — New MCP tool `list_touchpoints(thread_id)` returns
  all touchpoints for a thread ordered by inserted_at desc.

  Stage three touchpoints in sequence; list them and assert ordering is
  newest-first.

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

  spex "list_touchpoints returns all thread touchpoints newest-first" do
    scenario "three touchpoints staged in order [A, B, C] are listed as [C, B, A]" do
      given_ "an account with a thread", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "list001"})
        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "the agent stages A, B, C in order then lists", context do
        stage = fn body ->
          {:reply, resp, _} =
            StageResponse.execute(
              %{thread_id: context.thread.id, polished_body: body, link_target: "https://x"},
              context.frame
            )

          decoded = decode_payload(resp)
          decoded["touchpoint_id"] || decoded["id"]
        end

        id_a = stage.("Body A")
        # Tiny sleep so insertion timestamps differ deterministically on fast machines
        Process.sleep(20)
        id_b = stage.("Body B")
        Process.sleep(20)
        id_c = stage.("Body C")

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           payload: decode_payload(list_resp),
           id_a: id_a,
           id_b: id_b,
           id_c: id_c
         })}
      end

      then_ "list returns [C, B, A] in that order", context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []

        assert length(touchpoints) == 3,
               "expected 3 touchpoints, got #{length(touchpoints)}"

        ids = Enum.map(touchpoints, &(&1["id"] || &1[:id]))

        assert ids == [context.id_c, context.id_b, context.id_a],
               "expected newest-first ordering [C, B, A] = #{inspect([context.id_c, context.id_b, context.id_a])}, got #{inspect(ids)}"

        {:ok, context}
      end
    end
  end
end
