defmodule MarketMySpecSpex.Story716.Criterion6332Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6332 — Touchpoint schema gains an optional `angle` text
  field for the agent's reasoning on this specific comment.

  Asserts the angle field is observable through the agent surface:
  stage_response with an angle persists it; list_touchpoints reads it
  back. Optionality is covered by criterion 6354.

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

  spex "Touchpoint carries an angle text field; readable via list_touchpoints" do
    scenario "stage_response with angle persists the string and list_touchpoints exposes it" do
      given_ "an account with a Thread", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "ang001"})
        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "the agent stages a response with an angle string and lists touchpoints", context do
        {:reply, _stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "A polished body",
              link_target: "https://marketmyspec.com/x",
              angle: "Pivot to harness engineering as the missing piece"
            },
            context.frame
          )

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok, Map.put(context, :payload, decode_payload(list_resp))}
      end

      then_ "the touchpoint has angle equal to the supplied string", context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []

        refute Enum.empty?(touchpoints),
               "expected at least 1 touchpoint after stage_response, got empty"

        [tp | _] = touchpoints
        angle = tp["angle"] || tp[:angle]

        assert angle == "Pivot to harness engineering as the missing piece",
               "expected angle preserved on the Touchpoint, got: #{inspect(angle)}"

        {:ok, context}
      end
    end
  end
end
