defmodule MarketMySpecSpex.Story707.Criterion6506Spex do
  @moduledoc """
  Story 707 — Stage a Touchpoint from a Thread (synopsis, angle, UTM link)
  Criterion 6506 — A later stage with a different synopsis OVERWRITES the
  prior value.

  The original write-once semantics caused placeholder/test synopses to
  stick permanently when the agent staged a touchpoint with a stub value
  while iterating. Synopsis is now updated on every stage so the agent
  can refine its synthesis.

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

  spex "synopsis on parent Thread is overwritten on subsequent stages" do
    scenario "Two stages with different synopses; second value wins" do
      given_ "a fresh Reddit thread owned by Sam with nil synopsis", context do
        scope = Fixtures.account_scoped_user_fixture()

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

      when_ "agent stages once with a placeholder synopsis, then again with the real one", context do
        first_synopsis = "test synopsis"
        second_synopsis = "OP wants to learn idiomatic Elixir; pair with the small-programs series."

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
           second_synopsis: second_synopsis,
           after_first: after_first,
           after_second: after_second
         })}
      end

      then_ "after stage 1 the synopsis is the first value; after stage 2 it is the second", context do
        assert context.after_first == context.first_synopsis,
               "expected first synopsis to be written (observed via GetThread); got: #{inspect(context.after_first)}"

        assert context.after_second == context.second_synopsis,
               "expected second synopsis to overwrite first (observed via GetThread); got: #{inspect(context.after_second)}"

        {:ok, context}
      end
    end
  end
end
