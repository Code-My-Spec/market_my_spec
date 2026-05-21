defmodule MarketMySpecSpex.Story707.Criterion6506Spex do
  @moduledoc """
  Story 707 — Stage a Touchpoint from a Thread (synopsis, angle, UTM link)
  Criterion 6506 — A later stage with a different synopsis preserves the
  original.

  Once the parent Thread has a non-nil synopsis, subsequent stage_response
  calls passing a different synopsis must NOT overwrite it. Synopsis is
  captured once and preserved on subsequent stages — never an update path.
  The agent observes via the GetThread MCP tool between stages.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagement.Tools.GetThread
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

  defp synopsis_via_get_thread(thread_id, frame) do
    {:reply, get_resp, _} = GetThread.execute(%{thread_id: thread_id}, frame)
    get_in(decode_payload(get_resp), ["thread", "synopsis"])
  end

  spex "synopsis is write-once on the parent Thread" do
    scenario "Two stages with different synopses; second is ignored; first persists" do
      given_ "a fresh Reddit thread owned by Sam with nil synopsis", context do
        scope = Fixtures.account_scoped_user_fixture()

        # `fetched_at` + `op_body` set so GetThread skips the Reddit refresh
        # and just returns the cached payload (which is what these assertions
        # are about).
        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rt6506",
            subreddit: "elixir",
            op_body: "OP body for freshness check.",
            fetched_at: DateTime.utc_now()
          })

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent stages once with synopsis A, then again with synopsis B", context do
        first_synopsis = "First take — OP wants to learn idiomatic Elixir."
        second_synopsis = "Different take that should be ignored on second stage."

        {:reply, _, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              synopsis: first_synopsis,
              angle: "Point to the small Elixir programs blog series."
            },
            context.frame
          )

        after_first = synopsis_via_get_thread(context.thread.id, context.frame)

        {:reply, _, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              synopsis: second_synopsis,
              angle: "Suggest pairing with someone who has done a real migration."
            },
            context.frame
          )

        after_second = synopsis_via_get_thread(context.thread.id, context.frame)

        {:ok,
         Map.merge(context, %{
           first_synopsis: first_synopsis,
           after_first: after_first,
           after_second: after_second
         })}
      end

      then_ "after stage 1 the synopsis is set; after stage 2 it is unchanged", context do
        assert context.after_first == context.first_synopsis,
               "expected first synopsis to be written (observed via GetThread); got: #{inspect(context.after_first)}"

        assert context.after_second == context.first_synopsis,
               "expected first synopsis preserved after second stage (observed via GetThread); got: #{inspect(context.after_second)}"

        {:ok, context}
      end
    end
  end
end
