defmodule MarketMySpecSpex.Story716.Criterion6355Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6355 — Posted transition with comment_url and posted_at
  succeeds.

  Sister to 6337's happy-path leg; pinned via Three Amigos scenario.
  Update succeeds, list shows state :posted plus the supplied
  comment_url and posted_at.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints
  alias MarketMySpec.McpServers.Engagements.Tools.StageResponse
  alias MarketMySpec.McpServers.Engagements.Tools.UpdateTouchpoint
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

  defp parse_dt(value) do
    cond do
      is_binary(value) ->
        {:ok, dt, _} = DateTime.from_iso8601(value)
        dt

      is_integer(value) ->
        DateTime.from_unix!(value)

      true ->
        nil
    end
  end

  spex "posted transition with comment_url + posted_at succeeds" do
    scenario "Staged → :posted with both fields supplied; list shows new state + fields" do
      given_ "a staged Touchpoint", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "pos355"})
        frame = build_frame(scope)

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{thread_id: thread.id, polished_body: "Body", link_target: "https://x"},
            frame
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        {:ok, Map.merge(context, %{frame: frame, thread: thread, touchpoint_id: touchpoint_id})}
      end

      when_ "agent transitions to :posted with comment_url + posted_at", context do
        common_url = "https://www.reddit.com/r/elixir/comments/pos355/_/xyz"
        common_posted_at = DateTime.utc_now() |> DateTime.truncate(:second)

        {:reply, update_resp, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: context.touchpoint_id,
              state: "posted",
              comment_url: common_url,
              posted_at: DateTime.to_iso8601(common_posted_at)
            },
            context.frame
          )

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           update_resp: update_resp,
           payload: decode_payload(list_resp),
           expected_url: common_url,
           expected_posted_at: common_posted_at
         })}
      end

      then_ "update succeeds; touchpoint is :posted with the supplied comment_url/posted_at",
            context do
        case context.update_resp do
          %Response{isError: false} -> :ok
          other -> flunk("expected update_touchpoint to succeed, got: #{inspect(other)}")
        end

        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []
        refute Enum.empty?(touchpoints)
        tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.touchpoint_id))
        assert tp, "expected touchpoint in list"

        assert (tp["state"] || tp[:state]) in ["posted", :posted]
        assert (tp["comment_url"] || tp[:comment_url]) == context.expected_url

        actual_posted_at = parse_dt(tp["posted_at"] || tp[:posted_at])
        assert actual_posted_at != nil, "expected posted_at populated"

        assert DateTime.diff(actual_posted_at, context.expected_posted_at, :second) |> abs() <= 2,
               "expected posted_at ≈ #{context.expected_posted_at}, got #{actual_posted_at}"

        {:ok, context}
      end
    end
  end
end
