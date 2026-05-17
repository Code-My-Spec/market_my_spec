defmodule MarketMySpecSpex.Story707.Criterion6408Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6408 — Reddit and ElixirForum threads get distinct UTM
  schemes derived from the parent Thread's source.

  Sister to 6401; pinned via Three Amigos scenario. The Thread's
  source (NOT a tool parameter, NOT a heuristic on the URL) drives the
  UTM scheme. Tool input is identical for both calls; output is
  source-distinct.

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

  defp body_for(payload, touchpoint_id) do
    touchpoints = payload["touchpoints"] || payload["list"] || []
    tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == touchpoint_id))
    tp && (tp["polished_body"] || tp[:polished_body])
  end

  spex "distinct UTM schemes derived from Thread.source" do
    scenario "Identical agent input on Reddit vs ElixirForum threads → distinct UTM-embedded URLs" do
      given_ "two Threads with the same link_target candidates but different sources", context do
        scope = Fixtures.account_scoped_user_fixture()

        reddit_thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rdt408",
            url: "https://www.reddit.com/r/vibecoding/comments/rdt408/_/"
          })

        forum_thread =
          Fixtures.thread_fixture(scope, %{
            source: :elixirforum,
            source_thread_id: "ef408",
            url: "https://elixirforum.com/t/questions/ef408"
          })

        {:ok,
         Map.merge(context, %{
           frame: build_frame(scope),
           reddit_thread: reddit_thread,
           forum_thread: forum_thread
         })}
      end

      when_ "agent stages on each with identical input (only thread_id differs)", context do
        link_target = "https://marketmyspec.com/post-x"
        body = "Body with link " <> link_target <> " inline."

        {:reply, reddit_resp, _} =
          StageResponse.execute(
            %{thread_id: context.reddit_thread.id, polished_body: body, link_target: link_target},
            context.frame
          )

        {:reply, forum_resp, _} =
          StageResponse.execute(
            %{thread_id: context.forum_thread.id, polished_body: body, link_target: link_target},
            context.frame
          )

        reddit_id = (decode_payload(reddit_resp))["touchpoint_id"] || (decode_payload(reddit_resp))["id"]
        forum_id = (decode_payload(forum_resp))["touchpoint_id"] || (decode_payload(forum_resp))["id"]

        {:reply, list_reddit, _} =
          ListTouchpoints.execute(%{thread_id: context.reddit_thread.id}, context.frame)

        {:reply, list_forum, _} =
          ListTouchpoints.execute(%{thread_id: context.forum_thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           reddit_id: reddit_id,
           forum_id: forum_id,
           reddit_payload: decode_payload(list_reddit),
           forum_payload: decode_payload(list_forum)
         })}
      end

      then_ "Reddit body carries reddit/comment/<subreddit>; ElixirForum carries elixirforum/reply/<category-slug>",
            context do
        reddit_body = body_for(context.reddit_payload, context.reddit_id)
        forum_body = body_for(context.forum_payload, context.forum_id)

        assert reddit_body, "expected Reddit touchpoint body"
        assert forum_body, "expected Forum touchpoint body"

        reddit_utm_pattern = ~r/utm_source=reddit&utm_medium=comment&utm_campaign=vibecoding/
        forum_utm_pattern = ~r/utm_source=elixirforum&utm_medium=reply&utm_campaign=questions/

        assert Regex.match?(reddit_utm_pattern, reddit_body),
               "expected Reddit UTM scheme in body; got: #{reddit_body}"

        assert Regex.match?(forum_utm_pattern, forum_body),
               "expected ElixirForum UTM scheme in body; got: #{forum_body}"

        refute Regex.match?(forum_utm_pattern, reddit_body),
               "expected Reddit body NOT to carry ElixirForum UTM"

        refute Regex.match?(reddit_utm_pattern, forum_body),
               "expected Forum body NOT to carry Reddit UTM"

        {:ok, context}
      end
    end
  end
end
