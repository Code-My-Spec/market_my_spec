defmodule MarketMySpecSpex.Story707.Criterion6508Spex do
  @moduledoc """
  Story 707 — Stage a Touchpoint from a Thread (synopsis, angle, UTM link)
  Criterion 6508 — stage_response makes zero outbound HTTP calls.

  Manual-paste model (per Reddit Responsible Builder Policy May 2026):
  MMS is never a Reddit "app" — stage_response never submits anything to
  Reddit, ElixirForum, or any other platform. The spec installs a Req
  plug that captures any outbound request against both source HTTP
  configurations and asserts the recorded list is empty after staging on
  both a Reddit and an ElixirForum Thread.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.StageResponse
  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  spex "stage_response on Reddit AND ElixirForum threads → zero HTTP calls" do
    scenario "Two stages with a Req recorder installed; recorded list stays empty" do
      given_ "two threads (Reddit + ElixirForum) and a Req recorder installed", context do
        scope = Fixtures.account_scoped_user_fixture()

        reddit_thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rt6508",
            subreddit: "elixir"
          })

        forum_thread =
          Fixtures.thread_fixture(scope, %{
            source: :elixirforum,
            source_thread_id: "ef6508",
            category_slug: "phoenix"
          })

        recorder = self()

        plug = fn req ->
          send(recorder, {:outbound_req, req.url, req.method})
          %{req | response: Req.Response.new(status: 599, body: "FORBIDDEN_IN_TEST")}
        end

        Application.put_env(:market_my_spec, :reddit_req_options, plug: plug)
        Application.put_env(:market_my_spec, :elixirforum_req_options, plug: plug)

        ExUnit.Callbacks.on_exit(fn ->
          Application.delete_env(:market_my_spec, :reddit_req_options)
          Application.delete_env(:market_my_spec, :elixirforum_req_options)
        end)

        {:ok,
         Map.merge(context, %{
           frame: build_frame(scope),
           reddit_thread: reddit_thread,
           forum_thread: forum_thread
         })}
      end

      when_ "agent stages on both threads in turn", context do
        for thread <- [context.reddit_thread, context.forum_thread] do
          {:reply, _, _} =
            StageResponse.execute(
              %{
                thread_id: thread.id,
                synopsis: "OP asks about something innocuous.",
                angle: "Point to existing community resources."
              },
              context.frame
            )
        end

        Process.sleep(10)

        recorded =
          for {:outbound_req, url, method} <- collect_messages([]) do
            {method, url}
          end

        {:ok, Map.put(context, :recorded, recorded)}
      end

      then_ "the recorder shows zero outbound HTTP requests for both stages", context do
        assert context.recorded == [],
               "expected ZERO outbound HTTP calls during two stage_response invocations (manual-paste policy); got: #{inspect(context.recorded)}"

        {:ok, context}
      end
    end
  end

  defp collect_messages(acc) do
    receive do
      {:outbound_req, _, _} = msg -> collect_messages([msg | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
