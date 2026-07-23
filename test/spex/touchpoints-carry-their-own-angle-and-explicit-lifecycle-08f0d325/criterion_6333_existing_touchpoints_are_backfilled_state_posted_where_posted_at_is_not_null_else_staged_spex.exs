defmodule MarketMySpecSpex.Story716.Criterion6333Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6333 — Existing touchpoints are backfilled: state = :posted
  where posted_at IS NOT NULL, else :staged.

  This is a migration-time concern. The spex pins the BEHAVIOR a
  consumer should observe post-migration: a Touchpoint created with
  only legacy fields (`posted_at` + `comment_url`) and no explicit
  `state` ends up in `:posted`; one created with neither ends up in
  `:staged`. We use the Touchpoint fixture (which would, post-migration,
  apply the same defaulting via the schema's default rule).

  Interaction surface: MCP tool execution (list_touchpoints reads
  derived state).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints
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

  spex "backfill: posted_at IS NOT NULL → :posted; absent → :staged" do
    scenario "two pre-existing touchpoints (one with posted_at, one without) report the right states" do
      given_ "an account with a thread and two touchpoints simulating the pre-migration shape",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "bf001"})

        # Simulate "legacy" touchpoint with posted_at + comment_url set,
        # no explicit state — post-migration this should be state :posted.
        legacy_posted =
          Fixtures.touchpoint_fixture(scope, thread, %{
            polished_body: "Legacy posted body",
            link_target: "https://marketmyspec.com/legacy-posted",
            comment_url: "https://www.reddit.com/r/elixir/comments/bf001/_/abc",
            posted_at: DateTime.utc_now() |> DateTime.add(-3600)
          })

        # Simulate "legacy" touchpoint without posted_at / comment_url —
        # post-migration this should be state :staged.
        legacy_staged =
          Fixtures.touchpoint_fixture(scope, thread, %{
            polished_body: "Legacy staged body",
            link_target: "https://marketmyspec.com/legacy-staged",
            comment_url: nil,
            posted_at: nil
          })

        {:ok,
         Map.merge(context, %{
           frame: build_frame(scope),
           thread: thread,
           legacy_posted_id: legacy_posted.id,
           legacy_staged_id: legacy_staged.id
         })}
      end

      when_ "the agent calls list_touchpoints", context do
        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok, Map.put(context, :payload, decode_payload(list_resp))}
      end

      then_ "the posted-shape row has state :posted; the staged-shape row has state :staged",
            context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []

        refute Enum.empty?(touchpoints),
               "expected 2 touchpoints, got empty list"

        assert length(touchpoints) == 2,
               "expected 2 touchpoints, got #{length(touchpoints)}"

        posted_tp =
          Enum.find(touchpoints, fn tp ->
            (tp["id"] || tp[:id]) == context.legacy_posted_id
          end)

        staged_tp =
          Enum.find(touchpoints, fn tp ->
            (tp["id"] || tp[:id]) == context.legacy_staged_id
          end)

        assert posted_tp, "expected to find the legacy-posted touchpoint"
        assert staged_tp, "expected to find the legacy-staged touchpoint"

        assert (posted_tp["state"] || posted_tp[:state]) in ["posted", :posted],
               "expected backfilled :posted, got: #{inspect(posted_tp["state"] || posted_tp[:state])}"

        assert (staged_tp["state"] || staged_tp[:state]) in ["staged", :staged],
               "expected default :staged, got: #{inspect(staged_tp["state"] || staged_tp[:state])}"

        {:ok, context}
      end
    end
  end
end
