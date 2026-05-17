defmodule MarketMySpecSpex.Story707.Criterion6412Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6412 — stage_response makes zero HTTP calls to Reddit or
  ElixirForum.

  Sister to 6406; pinned via Three Amigos scenario. Reasserts the
  manual-paste policy: stage_response is a UTM-embedder + row creator,
  never an HTTP caller. The test installs a request recorder against
  both Reddit and ElixirForum Req configurations.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
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

  spex "stage_response on Reddit AND ElixirForum threads → zero HTTP calls" do
    scenario "Recorder installed; two stages (reddit + forum); recorded list stays empty" do
      given_ "two Threads (reddit + elixirforum) and a Req request recorder", context do
        scope = Fixtures.account_scoped_user_fixture()

        reddit_thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "no412r",
            subreddit: "elixir"
          })

        forum_thread =
          Fixtures.thread_fixture(scope, %{
            source: :elixirforum,
            source_thread_id: "no412f",
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
          {:reply, _resp, _} =
            StageResponse.execute(
              %{
                thread_id: thread.id,
                polished_body: "Body https://x",
                link_target: "https://x"
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

      then_ "recorded list is empty for BOTH stages (no Reddit submit, no Discourse post)", context do
        assert context.recorded == [],
               "expected ZERO HTTP calls during two stage_response invocations (manual-paste policy); got: #{inspect(context.recorded)}"

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
