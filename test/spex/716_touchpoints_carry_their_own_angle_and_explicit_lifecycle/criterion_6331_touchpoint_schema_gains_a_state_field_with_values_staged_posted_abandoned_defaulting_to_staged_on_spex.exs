defmodule MarketMySpecSpex.Story716.Criterion6331Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6331 — Touchpoint schema gains a `state` field with values
  `:staged | :posted | :abandoned`, defaulting to `:staged` on create.

  Drive via `StageResponse` MCP tool — creates a new Touchpoint and then
  `ListTouchpoints` observes the new row's state. Default must be
  `:staged` (per R1's default).

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

  spex "stage_response creates a Touchpoint defaulting to state :staged" do
    scenario "newly-staged Touchpoint has state :staged when read back via list_touchpoints" do
      given_ "an account with a Thread", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "stg001"})
        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "the agent stages a response and lists the thread's touchpoints", context do
        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "A polished body",
              link_target: "https://marketmyspec.com/x"
            },
            context.frame
          )

        decoded_stage = decode_payload(stage_resp)
        touchpoint_id = decoded_stage["touchpoint_id"] || decoded_stage["id"]

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           touchpoint_id: touchpoint_id,
           payload: decode_payload(list_resp)
         })}
      end

      then_ "the new Touchpoint has state :staged", context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []

        refute Enum.empty?(touchpoints),
               "expected at least 1 touchpoint after stage_response, got empty list"

        new_tp =
          Enum.find(touchpoints, fn tp ->
            (tp["id"] || tp[:id]) == context.touchpoint_id
          end) || hd(touchpoints)

        assert (new_tp["state"] || new_tp[:state]) in ["staged", :staged],
               "expected default state :staged, got: #{inspect(new_tp["state"] || new_tp[:state])}"

        {:ok, context}
      end
    end
  end
end
