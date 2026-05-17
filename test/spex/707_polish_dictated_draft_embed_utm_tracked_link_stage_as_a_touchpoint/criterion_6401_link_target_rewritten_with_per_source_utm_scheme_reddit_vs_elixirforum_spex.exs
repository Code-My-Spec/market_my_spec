defmodule MarketMySpecSpex.Story707.Criterion6401Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6401 — `link_target` is rewritten with a per-source UTM
  scheme before embedding: Reddit uses
  `utm_source=reddit&utm_medium=comment&utm_campaign=<subreddit>`;
  ElixirForum uses
  `utm_source=elixirforum&utm_medium=reply&utm_campaign=<category-slug>`.

  Source-specific rewrite: same link_target, two different Threads
  (one Reddit, one ElixirForum) produce two different UTM-embedded
  links in their polished_body.

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

  spex "per-source UTM scheme: Reddit vs ElixirForum produce distinct UTM-embedded links" do
    scenario "Same link_target on two Threads (subreddit=elixir vs category=phoenix) — two URL forms" do
      given_ "two persisted Threads: one Reddit (sub: elixir), one ElixirForum (category: phoenix)",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        reddit_thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rdt401",
            subreddit: "elixir"
          })

        forum_thread =
          Fixtures.thread_fixture(scope, %{
            source: :elixirforum,
            source_thread_id: "ef401",
            url: "https://elixirforum.com/t/phoenix/ef401"
          })

        {:ok,
         Map.merge(context, %{
           frame: build_frame(scope),
           reddit_thread: reddit_thread,
           forum_thread: forum_thread
         })}
      end

      when_ "agent stages on each Thread with the same link_target", context do
        link_target = "https://marketmyspec.com/landing"

        {:reply, reddit_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.reddit_thread.id,
              polished_body: "Reddit body referencing https://marketmyspec.com/landing here",
              link_target: link_target
            },
            context.frame
          )

        {:reply, forum_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.forum_thread.id,
              polished_body: "Forum body referencing https://marketmyspec.com/landing here",
              link_target: link_target
            },
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

      then_ "Reddit body carries reddit/comment/<subreddit>; Forum carries elixirforum/reply/<category-slug>",
            context do
        reddit_body = body_for(context.reddit_payload, context.reddit_id)
        forum_body = body_for(context.forum_payload, context.forum_id)

        assert reddit_body, "expected reddit touchpoint body in list"
        assert forum_body, "expected forum touchpoint body in list"

        assert reddit_body =~ "utm_source=reddit",
               "expected Reddit body to carry utm_source=reddit; got: #{reddit_body}"

        assert reddit_body =~ "utm_medium=comment",
               "expected Reddit body to carry utm_medium=comment; got: #{reddit_body}"

        assert reddit_body =~ "utm_campaign=elixir",
               "expected Reddit body to carry utm_campaign=<subreddit (elixir)>; got: #{reddit_body}"

        assert forum_body =~ "utm_source=elixirforum",
               "expected Forum body to carry utm_source=elixirforum; got: #{forum_body}"

        assert forum_body =~ "utm_medium=reply",
               "expected Forum body to carry utm_medium=reply; got: #{forum_body}"

        assert forum_body =~ "utm_campaign=phoenix",
               "expected Forum body to carry utm_campaign=<category-slug (phoenix)>; got: #{forum_body}"

        refute reddit_body =~ "utm_source=elixirforum",
               "expected Reddit body to NOT carry elixirforum UTM; got: #{reddit_body}"

        refute forum_body =~ "utm_source=reddit",
               "expected Forum body to NOT carry reddit UTM; got: #{forum_body}"

        {:ok, context}
      end
    end
  end
end
