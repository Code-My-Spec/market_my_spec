defmodule MarketMySpecSpex.Story707.Criterion6502Spex do
  @moduledoc """
  Story 707 — Stage a Touchpoint from a Thread (synopsis, angle, UTM link)
  Criterion 6502 — Reddit and ElixirForum threads produce distinct
  utm_source and utm_medium values.

  The Thread's `source` (NOT a tool parameter, NOT a heuristic on the
  URL) drives the UTM scheme. Stage on a Reddit Thread → utm_source=reddit,
  utm_medium=comment. Stage on an ElixirForum Thread → utm_source=elixirforum,
  utm_medium=reply. Same agent input on both Threads, distinct UTM args
  stored on each Touchpoint.

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

  defp touchpoint_for(payload, id) do
    touchpoints = payload["touchpoints"] || payload["list"] || []
    Enum.find(touchpoints, &((&1["id"] || &1[:id]) == id))
  end

  defp field(tp, key), do: tp[key] || tp[String.to_atom(key)]

  spex "utm_source and utm_medium are derived from Thread.source" do
    scenario "Reddit thread → reddit/comment; ElixirForum thread → elixirforum/reply" do
      given_ "two Threads owned by Sam — one Reddit (r/elixir), one ElixirForum (#phoenix)", context do
        scope = Fixtures.account_scoped_user_fixture()

        reddit_thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rt6502",
            subreddit: "elixir"
          })

        forum_thread =
          Fixtures.thread_fixture(scope, %{
            source: :elixirforum,
            source_thread_id: "ef6502",
            category_slug: "phoenix"
          })

        {:ok,
         Map.merge(context, %{
           frame: build_frame(scope),
           reddit_thread: reddit_thread,
           forum_thread: forum_thread
         })}
      end

      when_ "agent stages on each thread with identical synopsis and angle", context do
        common_args = %{
          synopsis: "Question about Phoenix LiveView state management.",
          angle: "Point to the recent state-handoff refactor."
        }

        {:reply, reddit_resp, _} =
          StageResponse.execute(
            Map.put(common_args, :thread_id, context.reddit_thread.id),
            context.frame
          )

        {:reply, forum_resp, _} =
          StageResponse.execute(
            Map.put(common_args, :thread_id, context.forum_thread.id),
            context.frame
          )

        reddit_id =
          (decode_payload(reddit_resp))["touchpoint_id"] ||
            (decode_payload(reddit_resp))["id"]

        forum_id =
          (decode_payload(forum_resp))["touchpoint_id"] ||
            (decode_payload(forum_resp))["id"]

        {:reply, list_reddit, _} =
          ListTouchpoints.execute(%{thread_id: context.reddit_thread.id}, context.frame)

        {:reply, list_forum, _} =
          ListTouchpoints.execute(%{thread_id: context.forum_thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           reddit_tp: touchpoint_for(decode_payload(list_reddit), reddit_id),
           forum_tp: touchpoint_for(decode_payload(list_forum), forum_id)
         })}
      end

      then_ "Reddit touchpoint carries reddit/comment; ElixirForum touchpoint carries elixirforum/reply", context do
        assert context.reddit_tp, "expected Reddit touchpoint in list"
        assert context.forum_tp, "expected ElixirForum touchpoint in list"

        assert field(context.reddit_tp, "utm_source") == "reddit",
               "expected Reddit utm_source=reddit, got: #{inspect(field(context.reddit_tp, "utm_source"))}"

        assert field(context.reddit_tp, "utm_medium") == "comment",
               "expected Reddit utm_medium=comment, got: #{inspect(field(context.reddit_tp, "utm_medium"))}"

        assert field(context.forum_tp, "utm_source") == "elixirforum",
               "expected ElixirForum utm_source=elixirforum, got: #{inspect(field(context.forum_tp, "utm_source"))}"

        assert field(context.forum_tp, "utm_medium") == "reply",
               "expected ElixirForum utm_medium=reply, got: #{inspect(field(context.forum_tp, "utm_medium"))}"

        {:ok, context}
      end
    end
  end
end
