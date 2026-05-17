defmodule MarketMySpecSpex.Story716.Criterion6339Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6339 — `list_touchpoints` payload includes per-touchpoint:
  id, state, angle, polished_body, comment_url, posted_at, inserted_at.

  Stage one Touchpoint with angle; list it; assert all 7 keys present
  (`comment_url` and `posted_at` may be nil since not yet posted).

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

  @required_keys ~w(id state angle polished_body comment_url posted_at inserted_at)

  spex "list_touchpoints exposes all 7 required per-touchpoint keys" do
    scenario "single staged touchpoint reports id/state/angle/polished_body/comment_url/posted_at/inserted_at" do
      given_ "a thread with one staged touchpoint with angle", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "shp001"})
        frame = build_frame(scope)

        {:reply, _, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              polished_body: "Body shape probe",
              link_target: "https://marketmyspec.com/x",
              angle: "Angle shape probe"
            },
            frame
          )

        {:ok, Map.merge(context, %{frame: frame, thread: thread})}
      end

      when_ "the agent calls list_touchpoints", context do
        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok, Map.put(context, :payload, decode_payload(list_resp))}
      end

      then_ "the touchpoint carries all 7 required keys", context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []

        refute Enum.empty?(touchpoints), "expected 1 touchpoint, got empty"
        assert length(touchpoints) == 1

        [tp] = touchpoints

        for key <- @required_keys do
          assert Map.has_key?(tp, key),
                 "expected key '#{key}', got keys: #{inspect(Map.keys(tp))}"
        end

        # The :staged touchpoint should have nil for posting-only fields
        assert tp["state"] in ["staged", :staged]
        assert tp["angle"] == "Angle shape probe"
        assert tp["polished_body"] == "Body shape probe"
        assert tp["comment_url"] == nil
        assert tp["posted_at"] == nil
        assert tp["inserted_at"] != nil

        {:ok, context}
      end
    end
  end
end
