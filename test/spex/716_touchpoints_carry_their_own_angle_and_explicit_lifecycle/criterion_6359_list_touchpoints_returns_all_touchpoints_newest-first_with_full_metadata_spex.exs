defmodule MarketMySpecSpex.Story716.Criterion6359Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6359 — list_touchpoints returns all touchpoints newest-first
  with full metadata.

  Sister to 6338 (order) + 6339 (per-row fields); pinned via Three Amigos
  scenario. Three stages on the same thread, then list — three rows
  return in inserted_at-desc order, each carrying the full metadata set
  (id, state, angle, polished_body, comment_url, posted_at, inserted_at).

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

  spex "list_touchpoints returns three rows newest-first with full metadata per row" do
    scenario "Stage three (oldest→newest) with one posted; list returns all three in desc order with all fields" do
      given_ "a thread with three staged touchpoints (one transitioned to :posted)", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "ord359"})
        frame = build_frame(scope)

        # Stage three with distinct angles; sleep to ensure inserted_at ordering
        {:reply, first_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              polished_body: "First (oldest) body",
              link_target: "https://x/1",
              angle: "first angle"
            },
            frame
          )

        first_id =
          (decode_payload(first_resp))["touchpoint_id"] ||
            (decode_payload(first_resp))["id"]

        Process.sleep(1100)

        {:reply, second_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              polished_body: "Second body",
              link_target: "https://x/2",
              angle: "second angle"
            },
            frame
          )

        second_id =
          (decode_payload(second_resp))["touchpoint_id"] ||
            (decode_payload(second_resp))["id"]

        Process.sleep(1100)

        {:reply, third_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              polished_body: "Third (newest) body",
              link_target: "https://x/3",
              angle: "third angle"
            },
            frame
          )

        third_id =
          (decode_payload(third_resp))["touchpoint_id"] ||
            (decode_payload(third_resp))["id"]

        # Promote the middle one to :posted so we can verify posted_at + comment_url
        comment_url = "https://www.reddit.com/r/elixir/comments/ord359/_/middle"
        posted_at = DateTime.utc_now() |> DateTime.truncate(:second)

        {:reply, _, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: second_id,
              state: "posted",
              comment_url: comment_url,
              posted_at: DateTime.to_iso8601(posted_at)
            },
            frame
          )

        {:ok,
         Map.merge(context, %{
           frame: frame,
           thread: thread,
           first_id: first_id,
           second_id: second_id,
           third_id: third_id,
           comment_url: comment_url
         })}
      end

      when_ "agent calls list_touchpoints for the thread", context do
        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok, Map.put(context, :payload, decode_payload(list_resp))}
      end

      then_ "returns 3 rows newest-first; each carries id/state/angle/polished_body/comment_url/posted_at/inserted_at",
            context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []
        assert length(touchpoints) == 3, "expected 3 rows, got #{length(touchpoints)}"

        ids_in_order = Enum.map(touchpoints, &(&1["id"] || &1[:id]))

        assert ids_in_order == [context.third_id, context.second_id, context.first_id],
               "expected newest-first order [#{context.third_id}, #{context.second_id}, #{context.first_id}]; got #{inspect(ids_in_order)}"

        required_keys = ~w(id state angle polished_body comment_url posted_at inserted_at)

        for tp <- touchpoints do
          for key <- required_keys do
            assert Map.has_key?(tp, key),
                   "expected key #{inspect(key)} on every row; missing on #{inspect(tp)}"
          end
        end

        # Spot-check the promoted middle row carries the posted metadata
        middle = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.second_id))

        assert (middle["state"] || middle[:state]) in ["posted", :posted],
               "expected middle touchpoint state :posted; got: #{inspect(middle["state"] || middle[:state])}"

        assert (middle["comment_url"] || middle[:comment_url]) == context.comment_url
        assert (middle["posted_at"] || middle[:posted_at]) != nil
        assert (middle["angle"] || middle[:angle]) == "second angle"

        # Other two are :staged with nil posted metadata
        for {tp_id, expected_angle} <- [
              {context.first_id, "first angle"},
              {context.third_id, "third angle"}
            ] do
          tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == tp_id))

          assert (tp["state"] || tp[:state]) in ["staged", :staged],
                 "expected #{tp_id} state :staged"

          assert (tp["comment_url"] || tp[:comment_url]) == nil
          assert (tp["posted_at"] || tp[:posted_at]) == nil
          assert (tp["angle"] || tp[:angle]) == expected_angle
        end

        {:ok, context}
      end
    end
  end
end
