defmodule MarketMySpecSpex.Story707.Criterion6505Spex do
  @moduledoc """
  Story 707 — Stage a Touchpoint from a Thread (synopsis, angle, UTM link)
  Criterion 6505 — First stage with a synopsis writes that synopsis to
  the Thread.

  The first stage_response call on a Thread that has nil synopsis sets
  the parent Thread's synopsis field to the synopsis string the agent
  passed. The agent observes the change via the GetThread MCP tool which
  surfaces `synopsis` in its response payload.

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

  spex "stage_response writes synopsis onto the parent Thread when it is nil" do
    scenario "Thread starts with nil synopsis; agent stages with synopsis; GetThread surfaces it" do
      given_ "a fresh Reddit thread owned by Sam with nil synopsis", context do
        scope = Fixtures.account_scoped_user_fixture()

        # `fetched_at` + `op_body` set so GetThread treats the row as fresh
        # and returns the cached payload without making a Reddit refresh call.
        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rt6505",
            subreddit: "elixir",
            op_body: "OP body for freshness check.",
            fetched_at: DateTime.utc_now()
          })

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent calls stage_response with a synopsis, then reads the thread back via GetThread", context do
        synopsis = "OP catalogs four context tools but doesn't address structured-layer rot."

        {:reply, _stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              synopsis: synopsis,
              angle: "Lead with the harness-vs-chat split."
            },
            context.frame
          )

        {:reply, get_resp, _} =
          GetThread.execute(%{thread_id: context.thread.id}, context.frame)

        payload = decode_payload(get_resp)

        {:ok, Map.merge(context, %{expected_synopsis: synopsis, get_payload: payload})}
      end

      then_ "GetThread's response payload carries the synopsis the agent passed", context do
        synopsis_in_payload = get_in(context.get_payload, ["thread", "synopsis"])

        assert synopsis_in_payload == context.expected_synopsis,
               "expected GetThread payload.thread.synopsis to equal the passed synopsis; got: #{inspect(synopsis_in_payload)}"

        {:ok, context}
      end
    end
  end
end
